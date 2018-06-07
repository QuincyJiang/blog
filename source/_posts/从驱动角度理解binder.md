title: 	从驱动角度理解binder
date: 2018/06/02 19:00:50
categories: Android
comments: true
tags: [android,Binder]
---
一次binder通讯建立的大致流程我们已经了解了，首先是要注册一个serviceManager，server端创建实名binder，向smg注册自己可以提供的服务，以及该实名binder的标签，smg会在svcinfo 链表中缓存该server提供的binder信息，当client需要使用该服务时，只需要向smg中查询服务，获取server端binder的引用就可以了，这其中所有的通讯细节，全部需要binder驱动来实现。
![](/media/15280074117127.jpg)


本文主要总结一下对binder驱动的理解，了解驱动设计的细节，以及binder通讯过程中驱动主要做了哪些事情。
# Binder驱动的定义
Binder驱动其实是一种特殊的字符型驱动，实现方式类似硬件驱动，工作在内核态。
如果了解过linux驱动相关知识，应该知道`file_operations` 结构体的重要性，linux 使用该结构体访问驱动程序的函数，这个结构体的每一个成员的名字都对应一个内核调用。
当用户进程利用设备文件（binder对应的设备文件为/dev/test）对文件进行类似`read()/write()` 操作的时候，系统调用通过设备文件的主设备号找到对应的设备驱动程序，每一个驱动程序在内核中是由一个`cdev`结构体描述，`cdev`结构体中又包括一个成员`fops`结构体，fops便是`file_operations`类型的，然后读取`file_operations` 结构体相应的函数指针，接着把控制权交给该函数的linux 设备驱动程序工作。

下面以binder驱动在内核中的注册流程来分析binder驱动为用户空间定义了哪些可用来调用的函数。
 
##  注册Binder
 在binder驱动源码中（[kernel/drivers/staging/android/binder.c](https://elixir.bootlin.com/linux/v3.11.4/source/drivers/staging/android/binder.c)），通过调用 `ret = misc_register(&binder_msicdev)`函数完成向内核注册`binder`驱动，主设备号为10，次设备号动态分配， 其中传入的参数便是一个`miscdev`的结构体，
 它的定义如下
 
 ```c
static struct miscdevice binder_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "binder",
	.fops = &binder_fops
};
 ```
可以看到`cdev`文件中标注了`binder`设备的设备名"binder"，以及`fops`结构体，`fops`结构体如下：

```c
static const struct file_operations binder_fops = {
    .owner = THIS_MODULE,
    .poll = binder_poll,
    .unlocked_ioctl = binder_ioctl,
    .mmap = binder_mmap,
    .open = binder_open,
    .flush = binder_flush,
    .release = binder_release,
};
```
可以看到binder驱动为应用层提供了`open()`,`mmap()`,`poll()`,`ioctl()`等标准的文件操作【注1】，`open()`负责打开驱动，`mmap()`负责对`binder`做内核空间向用户空间的地址映射，`ioctl()`负责binder协议的通信。

我们知道，用户态的引用程序调用`kernel`驱动程序是会陷入内核态的，进行系统调用，比如我使用 `fd = open("dev/binder",O_RDWR)`，开打开`binder`驱动时，它会先通过通过系统调用` _open()`【注1】，通过主次设备号来找到对应的binder驱动程序，即在 `cdev` 链表中找到binder驱动对应的
`binder_miscdev`，找到 `binder_fops`结构体，找到`open()`方法对应的 `binder_open()`函数，实际执行到的便是`binder_open（）`函数。那么其他的 比如 mmap(),ioctl()方法，他们的执行流程也是类似的。 参考下图
![](/media/15280103450907.jpg)



> 注释1： open()为用户空间的方法，_open()为系统调用中对应的处理方法。

打开一次binder通讯，大致分为以下流程：

* 1 调用`open()`方法打开`binder`驱动 
* 2 调用 `mmap()`方法申请一块内存用来接受通信中的数据，并进行内存映射（binder机制为什么只进行一次拷贝，这里有文章），
* 3 调用 `ioctl()`方法 开启binder通讯。
这里每一步中具体都做了些什么，下文会有详细描述，但为了更好理解，需要先要搞清楚binder驱动中的几个关键的数据结构和binder的通讯协议。

## Binder驱动中的结构体

驱动中的结构体分为两部分，一部分与用户空间共用，这些结构体在Binder通信协议中会用到，被定义在binder.h 头文件中。
具体内容见下表：

| 结构体名 | 说明 |
| --- | --- |
| flat_binder_object | binder通讯过程中在client-binderDriver-server之间传递的实际内容，所谓跨进程传递的binder对象，其实传递的就是这个 |
| binder_wirte_read | 存储对binder驱动进行读写操作的数据，当为写的时候，结构体中的write_size非空，当为读的时候，read_size不为空 |
| binder_version | 存储binder的版本号 |
| transaction_flags | 描述一次binder事务的flag，比如是同步还是异步请求 |
| binder_transcation_data | 存储一次事务的数据 |
| binder_handle_cookie | 包含一个句柄和一个cookie |
| binder_ptr_cookie | 包含一个指针和一个cookie 
| binder_pri_dest | 暂未用到 
| binder_pri_ptr_cookie | 暂未用到 |

另一部分定义在binder驱动中，是驱动特有的结构体


| 结构体名 | 描述 |
| --- | --- |
| binder_node | 描述binder的实体节点，对应一个server，当server通过binder驱动向smg注册时，binder驱动便会在内核中为其创建一个binder实体节点，该实体节点即为binder_node，同时驱动会为server与该节点创建引用关系 |
| binder_ref | 描述对binder实体节点的引用 |
| binder_buffer | 描述binder通讯过程中存储数据的buffer |
| binder_proc | 描述使用binder的进程 |
| binder_thread | 描述使用binder的线程 |
| binder_work | 描述通信过程中的一项任务 |
| binder_transcation | 描述一次事务的相关信息 |
| binder_deferred_state | 藐视延迟任务 |
| binder_ref_death | 描述binder实体的死亡信息  |
| binder_transcation_log | debugfs 日志 |
| binder_transcation_log_entry | debugfs 日志条目 |


## binder协议
Binder协议 可以分为 **控制协议**和**驱动协议**两部分。

### 1.控制协议
**控制协议**是进程(client 或server端)通过系统调用（syscall）直接操作binder设备文件，使用`ioctl('dev/binder')`控制binder驱动的协议，该协议包含以下几种命令

| 命令 | 含义 | 参数 |
| --- | --- | --- |
| BINDER_WRITE_READ | 该命令想binder写入或者读出数据，参数分为两段，写和度部分，如果write_size不为零，就先将write_buffer中的数据写入binder； 如果read_size不为零，就先从binder中取出数据，写入read_buffer中。 write_consumed和read_consumed 表示操作完成时驱动实际写入和读出的数据个数。 | struct binder_wirte_read{ Singned long write_size;Signed long write_consumed;unsigend long write_buffer;signed long read_size;signed long read_consumed;Unsigned long read_buffer} |
| BINDER_SET_MAX_THREADS | 告知binder驱动接收方(server端)，线程池中最大的线程数。（详见下文 驱动线程管理） |int max_threads |
| BINDER_SET_CONEXT_MGR | 将当前进程注册为smg，系统同时只可以出现一个smg，只要当前smg没有调用close关闭binder驱动，就不可能有别的进程可以成为smg | |
| BINDER_THREAD_EXIT |  通知binder驱动当前线程退出了，binder会为所有参与binder通信的线程（包括server端线程池中的线程以及client端发出请求的线程）建立相应的数据结构，这些线程在退出时必须显示通知binder释放相应的数据。详见下文 binder驱动的线程控制 |  |

### 2. 驱动协议
驱动协议根据具体使用过程，又分为**发送**和**返回**协议。
**发送协议** 定义在`binder.c ` 中的
 ```c
 enum binder_driver_command_protocol
 ```
，**返回协议 ** 定义在 
```c
 enum binder_driver_return_protocol
 ```
 
 根据协议不同，存放的位置也不相同。
驱动协议都是封装在控制协议   `BINDER_WRITE_READ` 命令参数 `binder_wirte_read` 结构体中，根据发送和返回类型，分别存放在 `write_buffer`和 `read_buffer`域所指向的内存空间中。
`binder_write_read`结构体的数据结构见下图：
![](/media/15280146752888.jpg)


它们的数据格式都是命令 + 数据 的格式，多条命令可以连续存放。数据紧接着放在命令的后面，根据命令不同，执行的操作也不同。

#### 发送协议：








| 命令 | 说明 | 参数 |
| --- | --- | --- |
| BC_TRANSCATION | binder事务，client对server的请求 | binder_transction_data |
| BC_REPLAY | 事务的回答，server对client的回复 | Binder_transctin_data |
| BC_FREE_BUFFER | 通知驱动释放buffer | Binder_uinptr_t |
| BC_ACQUIRE | 强引用计数+1 | _u32 |
| BC_RELEASE | 强引用计数-1 | _u32 |
| BC_INCREFS | 弱引用计数+1 | _u32 |
| BC_DECREFS | 弱引用计数-1 | _u32 |
| BC_ACQUIRE_DODE | acquire指令的回复 | Binder_ptr_cookie |
| BC_INCREFS_DONE | increfs指令的回复 | Binder_prt_cookie |
| BC_ENTER_LOOPER | 通知驱动主线程ready | Void |
| BC_REGISTER_LOOPER | 通知驱动子线程ready | Void |
| BC_EXIT_LOOPER | 通知驱动线程已退出 | Void |
| BC_REQUEST_DEATH_NOTIFICATION | 请求接受死亡通知 | Binder_handle_cookie |
| BC_CLEAR_DEATH_NOTIFICATION | 去除接受死亡通知 | Binder_handle_cookie |
| BC_DEAD_BINDER_DONE | 已经处理完死亡通知 | Binder_uinptr_t |
| BC_ATTEMPT_ACQUIRE | 暂未实现  | - |
| BC_ACQUIRE_RESULT | 暂为实现 | - |

#### 返回协议：

| 命令 | 说明 | 参数 |
| --- | --- | --- |
| BR_OK |操作完成 | void |
| BR_NOOP |操作完成 | void |
| BR_ERROR | 发生错误 |_s32 |
| BR_TRANSCATION | 进程收到一次binder请求 （server端）| binder_transcation_data |
| BR_REPLAY | 进程收到binder请求的回复（client） | binder_transtaction_data |
| BR_TRANSCATION_COMPLETED | 驱动对于接收请求的确认回复 | void |
| BR_FAILED_REPLAY | 告知发送方 通信目标不存在 | void |
| BR_SPAWN_LOOPER | 通server端创建一个新的进程 | void |
| BR_ACQUIRE | 强用用计数+1 | Binder_prt_cookie |
| BR_RELEASE | 强引用计数-1 | Binder_prt_cookie |
| BR_INCREFS | 弱引用计数+1 | Binder_prt_cookie |
| BR_DECREFS | 弱引用计数-1 | Binder_prt_cookie |
| BR_DEAD_BINDER |发送死亡通知 | binder_uintptr_t |
| BR_CLEAR_DEATH_NOTIFICATION_DONE | 清除死亡通知完成 | binder_uintptr_t |
| BR_DEAD_REPLAY | 改制发送方对方已死亡 | void |
| BR_ATTEMPT_ACQUIRE | 暂未实现  | - |
| BR_ACQUIRE_RESULT | 暂为实现 | - |
| BR_FINISHED | 暂未实现| - |

#### binder 请求的过程

见下图：

![](/media/15280173877321.jpg)

通过上面的Binder协议的说明中我们看到，Binder协议的通信过程中，不仅仅是发送请求和接受数据这些命令。同时包括了对于引用计数的管理和对于死亡通知的管理（告知一方，通讯的另外一方已经死亡）等功能。

这些功能的通信过程和上面这幅图是类似的：一方发送`BC_XXX`，然后由驱动控制通信过程，接着发送对应的`BR_XXX`命令给通信的另外一方。因为这种相似性，对于这些内容就不再赘述了。

### 由驱动角度理解 Binder通讯建立的过程

#### 1 打开驱动（open("dev/binder")）

任何进程在使用Binder之前，都需要先通过`open("/dev/binder")`打开Binder设备。上文已经提到，用户空间的`open`系统调用对应了驱动中的`binder_open`函数。在这个函数，Binder驱动会为调用的进程做一些初始化工作。`binder_open`函数代码如下所示

```c
static int binder_open(struct inode *nodp, struct file *filp)
{
	struct binder_proc *proc;

   // 创建进程对应的binder_proc对象 
	proc = kzalloc(sizeof(*proc), GFP_KERNEL); 
	if (proc == NULL)
		return -ENOMEM;
	get_task_struct(current);
	proc->tsk = current;
	// 初始化binder_proc
	INIT_LIST_HEAD(&proc->todo);
	init_waitqueue_head(&proc->wait);
	proc->default_priority = task_nice(current);

  // 锁保护
	binder_lock(__func__);

	binder_stats_created(BINDER_STAT_PROC);
	// 添加到全局列表binder_procs中
	hlist_add_head(&proc->proc_node, &binder_procs);
	proc->pid = current->group_leader->pid;
	INIT_LIST_HEAD(&proc->delivered_death);
	filp->private_data = proc;

	binder_unlock(__func__);

	return 0;
}
```

可以看到，在打开binder驱动时，`binder_procs`会将所有打开binder驱动的进程加入到该列表中，上文中提到binder中的几个主要结构体，其实都是通过`binder_procs`结构体链接在一起的。

![](/media/15280179417192.jpg)


#### 2. 创建内存空间并实现用户空间 内核空间的映射（mmap）

打开binder驱动之后，进程会通过`mmap()`方法进行内存空间的映射。 

上文描述过，`mmap()`对应的`binder_mmap()`函数，它会先申请一份物理内存，默认`PAGE_SIZE` 是4k，然后会**同时在 用户空间和 内核空间**映射该物理内存。当client 发送数据给server的时候，只需要将client端的数据，拷贝到server端所指向的 内核中的地址即可，因为server的用户空间和binder对应的内核空间映射的是同一份物理内存，当server取数据的时候，就无需再从内科中拷贝了，server可以直接使用。

![](/media/15280184528253.jpg)

这幅图的说明如下：

Server在启动之后，对`/dev/binder`设备调用`mmap`
内核中的`binder_mmap`函数进行对应的处理：申请一块物理内存，然后在用户空间和内核空间同时进行映射

Client通过`BINDER_WRITE_READ`命令发送请求，这个请求将先到驱动中，同时需要将数据从`Client`进程的用户空间拷贝到内核空间
驱动通过`BR_TRANSACTION`通知Server有人发出请求，Server进行处理。由于这块内存也在用户空间进行了映射，因此Server进程的代码可以直接访问


#### 3. 内存管理（非重点）
上文中，我们看到`binder_mmap`的时候，会申请一个`PAGE_SIZE`通常是4K的内存。而实际使用过程中，一个`PAGE_SIZE`的大小通常是不够的。

在驱动中，会根据实际的使用情况进行内存的分配。有内存的分配，当然也需要内存的释放。这里我们就来看看Binder驱动中是如何进行内存的管理的。

首先，我们还是从一次IPC请求说起。

当一个Client想要对Server发出请求时，它首先将请求发送到Binder设备上，由Binder驱动根据请求的信息找到对应的目标节点，然后将请求数据传递过去。

进程通过ioctl系统调用来发出请求：`ioctl(mProcess->mDriverFD, BINDER_WRITE_READ, &bwr)`

PS：这行代码来自于Framework层的`IPCThreadState`类。在后文中，我们将看到，`IPCThreadState`类专门负责与驱动进行通信。

这里的`mProcess->mDriverFD`对应了打开Binder设备时的`fd`。`BINDER_WRITE_READ`对应了具体要做的操作码，这个操作码将由Binder驱动解析。`bwr`存储了请求数据，其类型是`binder_write_read`。

`binder_write_read`其实是一个相对外层的数据结构，其内部会包含一个`binder_transaction_data`结构的数据。`binder_transaction_data`包含了发出请求者的标识，请求的目标对象以及请求所需要的参数。它们的关系如下图所示：

![](/media/15280191293122.jpg)

`binder_ioctl`函数对应了`ioctl`系统调用的处理。这个函数的逻辑比较简单，就是根据`ioctl`的命令来确定进一步处理的逻辑，具体如下:

如果命令是`BINDER_WRITE_READ`，并且
如果 `bwr.write_size > 0`，则调用`binder_thread_write`
该方法用于处理Binder协议中的请求码。当`binder_buffer`存在数据，binder线程的写操作循环执行。对于请求码为`BC_TRANSACTION`或`BC_REPLY`时，会执行`binder_transaction`()方法，这是最为频繁的操作。 对于其他命令则不同。


如果 `bwr.read_size > 0`，则调用`binder_thread_read`，该方法用以处理响应过程，根据不同的`binder_work->type`以及不同状态，生成相应的响应码。

如果命令是`BINDER_SET_MAX_THREADS`，则设置进程的`max_threads`，即进程支持的最大线程数
如果命令是`BINDER_SET_CONTEXT_MGR`，则设置当前进程为`ServiceManager`，见下文
如果命令是`BINDER_THREAD_EXIT`，则调用`binder_free_thread`，释放`binder_thread`
如果命令是`BINDER_VERSION`，则返回当前的Binder版本号
这其中，最关键的就是`binder_thread_write`方法。当Client请求Server的时候，便会发送一个`BINDER_WRITE_READ`命令，同时框架会将将实际的数据包装好。此时，`binder_transaction_data`中的code将是`BC_TRANSACTION`，由此便会调用到`binder_transaction`方法，这个方法是对一次Binder事务的处理，这其中会调用`binder_alloc_buf`函数为此次事务申请一个缓存。
调用关系见下图
![](/media/15280210111665.jpg)

`binder_update_page_range`这个函数在上文中，我们已经看到过了。其作用就是：进行内存分配并且完成内存的映射。而`binder_alloc_buf`函数，正如其名称那样的：完成缓存的分配。

在驱动中，通过`binder_buffer`结构体描述缓存。一次Binder事务就会对应一个`binder_buffer`，
进程在mmap时，会设定支持的总缓存大小的上限。而进程每当收到`BC_TRANSACTION`，就会判断已使用缓存加本次申请的和有没有超过上限。如果没有，就考虑进行内存的分配。

进程的空闲缓存记录在`binder_proc`的`free_buffers`中，这是一个以红黑树形式存储的结构。每次尝试分配缓存的时候，会从这里面按大小顺序进行查找，找到最接近需要的一块缓存。找到之后，还要对binder_proc的字段进行更新。

`BC_FREE_BUFFER`命令是通知驱动进行内存的释放，`binder_free_buf`函数是真正实现的逻辑，这个函数与`binder_alloc_buf`是刚好对应的。在这个函数中，所做的事情包括：

* 重新计算进程的空闲缓存大小
* 通过`binder_update_page_range`释放内存
* 更新`binder_proc`的`buffers`，`free_buffers`，`allocated_buffers`字段

#### 4 通讯过程

`BINDER_COMMAND_PROTOCOL`：binder请求码，以”BC_“开头，简称BC码，用于从IPC层传递到Binder Driver层；
`BINDER_RETURN_PROTOCOL` ：binder响应码，以”BR_“开头，简称BR码，用于从Binder Driver层传递到IPC层；

一次完整的binder通讯流程：
![](/media/15280207692595.jpg)**Binder IPC通信至少是两个进程的交互**：

* client进程执行`binder_thread_write`，`thread_write`根据`BC_XXX`命令，生成相应的`binder_work`；
* server进程执行`binder_thread_read`，`thread_read`根据`binder_work.type`类型，生成`BR_XXX`，发送到用户空间处理。
![](/media/15280214808773.jpg)

`binder_work.type` ：
```c
BINDER_WORK_TRANSACTION //最常见类型
BINDER_WORK_TRANSACTION_COMPLETE
BINDER_WORK_NODE
BINDER_WORK_DEAD_BINDER
BINDER_WORK_DEAD_BINDER_AND_CLEAR
BINDER_WORK_CLEAR_DEATH_NOTIFICATION
```


可以知道，上述通信流程涉及到三种状态码的转换：
`BR_CODE` `BC_CODE`  `BW_CODE`,
他们之间的转换图如下：

![](/media/15280221155795.jpg)

![](/media/15280221222039.jpg)

图解：(以`BC_TRANSACTION`为例)

发起端进程：`binder_transaction`()过程将`BC_TRANSACTION`转换为`BW_TRANSACTION`；
接收端进程：`binder_thread_read`()过程，将`BW_TRANSACTION`转换为`BR_TRANSACTION`;
接收端进程：`IPC.execute()`过程，处理`BR_TRANSACTION`命令

以gityuan的一张图来总结binder通信的全过程

![](/media/15280227943358.jpg)

#### 5 通讯过程中 binder实体的传递

Binder机制淡化了进程的边界，使得跨越进程也能够调用到指定服务的方法，其原因是因为Binder机制在底层处理了在进程间的“对象”传递。

在Binder驱动中，并不是真的将对象在进程间来回序列化，而是通过特定的标识来进行对象的传递。Binder驱动中，通过`flat_binder_object`来描述需要跨越进程传递的对象。其定义如下：
```c
struct flat_binder_object {
	__u32		type;
	__u32		flags;

	union {
		binder_uintptr_t	binder; /* local object */
		__u32			handle;	/* remote object */
	};
	binder_uintptr_t	cookie;
};
```
这其中，type有如下5种类型。
```c
enum {
	BINDER_TYPE_BINDER	= B_PACK_CHARS('s', 'b', '*', B_TYPE_LARGE),
	BINDER_TYPE_WEAK_BINDER	= B_PACK_CHARS('w', 'b', '*', B_TYPE_LARGE),
	BINDER_TYPE_HANDLE	= B_PACK_CHARS('s', 'h', '*', B_TYPE_LARGE),
	BINDER_TYPE_WEAK_HANDLE	= B_PACK_CHARS('w', 'h', '*', B_TYPE_LARGE),
	BINDER_TYPE_FD		= B_PACK_CHARS('f', 'd', '*', B_TYPE_LARGE),
};
```
当对象传递到Binder驱动中的时候，由驱动来进行翻译和解释，然后传递到接收的进程。

例如当Server把Binder实体传递给Client时，在发送数据流中，`flat_binder_object`中的type是`BINDER_TYPE_BINDER`，同时binder字段指向Server进程用户空间地址。但这个地址对于Client进程是没有意义的（Linux中，每个进程的地址空间是互相隔离的），驱动必须对数据流中的`flat_binder_object`做相应的翻译：将type该成`BINDER_TYPE_HANDLE`；为这个Binder在接收进程中创建位于内核中的引用并将引用号填入handle中。对于发生数据流中引用类型的Binder也要做同样转换。经过处理后接收进程从数据流中取得的Binder引用才是有效的，才可以将其填入数据包`binder_transaction_data`的`target.handle`域，向Binder实体发送请求。

由于每个请求和请求的返回都会经历内核的翻译，因此这个过程从进程的角度来看是完全透明的。进程完全不用感知这个过程，就好像对象真的在进程间来回传递一样。

#### 6 驱动层的线程管理

上文多次提到，Binder本身是C/S架构。由Server提供服务，被Client使用。既然是C/S架构，就可能存在多个Client会同时访问Server的情况。 在这种情况下，如果Server只有一个线程处理响应，就会导致客户端的请求可能需要排队而导致响应过慢的现象发生。解决这个问题的方法就是引入多线程。

Binder机制的设计从最底层–驱动层，就考虑到了对于多线程的支持。具体内容如下：

* 使用Binder的进程在启动之后，通过`BINDER_SET_MAX_THREADS`告知驱动其支持的最大线程数量
* 驱动会对线程进行管理。在`binder_proc`结构中，这些字段记录了进程中线程的信息：`max_threads，requested_threads，requested_threads_started，ready_threads`
* `binder_thread`结构对应了Binder进程中的线程
* 驱动通过`BR_SPAWN_LOOPER`命令告知进程需要创建一个新的线程
* 进程通过`BC_ENTER_LOOPER`命令告知驱动其主线程已经ready
* 进程通过`BC_REGISTER_LOOPER`命令告知驱动其子线程（非主线程）已经ready
* 进程通过`BC_EXIT_LOOPER`命令告知驱动其线程将要退出
* 在线程退出之后，通过`BINDER_THREAD_EXIT`告知Binder驱动。驱动将对应的`binder_thread`对象销毁


