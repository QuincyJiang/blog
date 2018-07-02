title: 从一次native端的IPC流程理解binder
date: 2018/06/24 19:00:50
categories: Android
comments: true
tags: [android,Binder]
---


# 概述
本文是看完邓凡平的《深入理解android卷1》第六章的binder篇后，在此基础上的一些个人理解。
上文从驱动角度解释了`binder`通讯机制的底层运行原理，我们知道android系统中，`binder`是采用CS架构来设计的，除了`binderDriver`之外，还需要`client` `server` 以及`serviceManager` 三个角色，才能完整实现一套CS架构的跨进程通讯机制。
![](/media/15298368998935.jpg)


从上图可以看到，一次完整的IPC 至少需要这么几个步骤
1. `Server` 通过`serviceManager` 注册服务
2. `Client` 通过`ServiceManager` 查询服务
3. `Client` 获取到`Server`端的服务后，通过`binder`驱动，完成跨进程对`Server`端的引用。
下面以native层的一次IPC请求流程为例，通过client对MediaServer的调用，了解一下`client`、`server`、`serviceManager`三者之间的通讯过程。

# server端：MediaServer

`MediaServer` 是系统主要`server`之一，它提供了
1. AudioFlinger
2. AudioPolicyService
3. MediaplayerService
4. CamerService 
四个重量级服务，查看`MediaServer`的源码：

```c
int main(int argc, char** argv)
{
  //①获得一个ProcessState实例
 sp<ProcessState>proc(ProcessState::self());
 
 //②MS作为ServiceManager的客户端，需要向ServiceManger注册服务
 //调用defaultServiceManager，得到一个IServiceManager。
 sp<IServiceManager>sm = defaultServiceManager();
 
 //初始化音频系统的AudioFlinger服务
 AudioFlinger::instantiate();
 //③多媒体系统的MediaPlayer服务，我们将以它作为主切入点
 MediaPlayerService::instantiate();
 //CameraService服务
 CameraService::instantiate();
 //音频系统的AudioPolicy服务
 AudioPolicyService::instantiate();
 
 //④新建一个用以处理binder请求的线程
 ProcessState::self()->startThreadPool();
 //⑤将主线程也用来处理binder请求
 IPCThreadState::self()->joinThreadPool();
}
```
以代码中标注的1，2，3，4，5为次序，依次讲解每个部分的具体内容。
## 一、创建ProcessState
还是先看代码

```c
 //①获得一个ProcessState实例
 sp<ProcessState>proc(ProcessState::self());

```
创建ProcessState实例

```c
sp<ProcessState> ProcessState::self()
{
   //gProcess是在Static.cpp中定义的一个全局变量
   //程序刚开始执行，gProcess一定为空
    if(gProcess != NULL) return gProcess;
        AutoMutex_l(gProcessMutex);
     //创建一个ProcessState对象，并赋值给gProcess
    if(gProcess == NULL) gProcess = new ProcessState;
 
     return gProcess;
}
```

### 1 processState 的构造函数

```c
ProcessState::ProcessState()
   /*
    【笔记一：】
    注意 在构造ProcessState时，通过open_driver()函数 打开了binder驱动，并将binder驱动的
    fd赋值给了ProcessState的mDriverFD 成员变量。后面我们可以看到一个与ProcessState对应的
    IPCThreadState对象（它是线程单例），它的构造函数会以ProcessState做参数，ProcessState持
    有Binder驱动的句柄，所以IPCThreadState可以操作Binder驱动，事实上，IPCThread也就是循环
    读写binder驱动，从中拿消息并处理消息的。
   */
    :mDriverFD(open_driver())
    ,mVMStart(MAP_FAILED)//映射内存的起始地址
    ,mManagesContexts(false)
    ,mBinderContextCheckFunc(NULL)
    , mBinderContextUserData(NULL)
    ,mThreadPoolStarted(false)
    ,mThreadPoolSeq(1)
{
  if(mDriverFD >= 0) {
/*
    BIDNER_VM_SIZE定义为(1*1024*1024) - (4096 *2) = 1M-8K
    【笔记二：】
    上文驱动篇讲过，用户空间调用驱动的mmap，实际对应驱动层的binder_mmap()方法，
    在该方法里，binder驱动会申请一块用来存储通信数据的内存区域，其实就是binder驱动中一个叫做
    binder_buff的结构体。同时会在server进程的用户空间和内核空间做一次虚拟地址映射。这是为什么 
    binder通讯只进行一次拷贝的原因，上文已讲过这里不再详述。
*/
  mVMStart = mmap(0, BINDER_VM_SIZE, PROT_READ,MAP_PRIVATE | MAP_NORESERVE,
                     mDriverFD, 0);
    }
    ......
}

```

`processState` 是个单例对象，因为它是在程序运行时只初始化一次，所以每个进程只有一个`ProcessState`对象。在创建`ProcessState`时，做了这么几件事情
1. 打开`binder`驱动
2. 映射内存起始地址
3. 为`binder`驱动分配内存用以接受请求数据
### 2 打开binder驱动（open_driver()）
**ProcessState.cpp**

```c
static int open_driver()
{
    int fd =open("/dev/binder", O_RDWR);//打开/dev/binder设备
    if (fd>= 0) {
         ......
       size_t maxThreads = 15;
       //通过ioctl方式告诉binder驱动，这个fd支持的最大线程数是15个
       result = ioctl(fd, BINDER_SET_MAX_THREADS, &maxThreads);  
   }
return fd;
......
}
```
【笔记三：】
上文已经说过，`open('dev/binder',O_RDWR)` 其实对应了内核中`binder`驱动的`binder_open（）`方法，
`binder_open() `的代码如下：

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
可以看到，在打开`binder`驱动时，`binder_procs`会将所有打开`binder`驱动的进程加入到该列表中。
同时，通过`ioctrl` 的方式 告诉了`binder` 驱动 当前`server`端线程池支持的最大线程数是15.

所以创建`processState`的过程 其实做了这么几件事：
1. 打开`binder`驱动 同时驱动为该进程创建对应的`binder_proc` 节点 
2. 对返回的`fd` 使用`mmap`方法，操作`binder`驱动，`binder`驱动申请了一块内存来接受通讯数据
3. 因为`ProcessState`是进程单例的，每个进程只会开启`binder`驱动一次。
 
## 二、 获取servicManager
`defaultServiceManager()`方法在`IServiceManager.cpp`中定义，返回`IServiceManager`对象，先看一下这个方法的具体实现
**IServiceManager.cpp**

```c
 sp<IServiceManager> defaultServiceManager()
  {
    // 单例实现
    if(gDefaultServiceManager != NULL) return gDefaultServiceManager;
     {
       AutoMutex _l(gDefaultServiceManagerLock);
        if(gDefaultServiceManager == NULL) {
          //真正的gDefaultServiceManager是在这里创建的。
           gDefaultServiceManager = interface_cast<IServiceManager>(
                                   ProcessState::self()->getContextObject(NULL));
        }
    }
   returngDefaultServiceManager;
}
```
可以看到 真正的`IServiceManager` 是由方法 `interface_cast<IServiceManager>（）` 传入一个 `ProcessState::self()->getContextObject(NULL)`对象实现的。
先看一下`ProcessState::self()`的`getContextObject()`函数
**ProcessState.cpp**

```c
sp<IBinder>ProcessState::getContextObject(const sp<IBinder>& caller)
{
   /*
    caller的值为0！注意，该函数返回的是IBinder。它是什么？我们后面再说。
    supportsProcesses函数根据openDriver函数打开设备是否成功来判断是否支持process
    真实设备肯定支持process。
   */
  if(supportsProcesses()) {
   //真实设备上肯定是支持进程的，所以会调用下面这个函数
   //【笔记三：传的参数是null 所以handle号是0】
       return getStrongProxyForHandle(0);
    } else {
       return getContextObject(String16("default"), caller);
    }
}
```

继续看`getStrongProxyForHandle()`

**ProcessState.cpp**

```c
sp<IBinder>ProcessState::getStrongProxyForHandle(int32_t handle)
{
   sp<IBinder> result;
 AutoMutex_l(mLock);
    /*
    根据索引查找对应资源。如果lookupHandleLocked发现没有对应的资源项，则会创建一个新的项并返   
    回。
    这个新项的内容需要填充。
    */
   handle_entry* e = lookupHandleLocked(handle);
    if (e !=NULL) {
       IBinder* b = e->binder;
        if (b== NULL || !e->refs->attemptIncWeak(this)) {
           //对于新创建的资源项，它的binder为空，所以走这个分支。注意，handle的值为0
            b= new BpBinder(handle); //创建一个BpBinder
           e->binder = b; //填充entry的内容
           if (b) e->refs = b->getWeakRefs();
           result = b;
        }else {
           result.force_set(b);
           e->refs->decWeak(this);
        }
    }
    returnresult; //返回BpBinder(handle)，注意，handle的值为0
}
```
可以看到 实际返回的对象是一个`BpBinder`，`BpBinder`里持有一个`handle`成员变量。
实际上 `BpBinder` `BBinder` 都是继承自`IBinder`的。
![](/media/15298408964173.jpg)

从名字也可以看出来，`BpBinder` ,BProxy（proxy:代理），肯定是与客户端打交道的。如果说`Proxy`代表客户端，那么`BBinder`则代表服务端。这里的`BpBinder`和`BBinder`是一一对应的，即某个`BpBinder`只能和对应的`BBinder`交互。我们当然不希望通过`BpBinderA`发送的请求，却由`BBinderB`来处理。
刚才我们在`defaultServiceManager()`函数中创建了这个`BpBinder`。
前面说了，`BpBinder`和`BBinder`是一一对应的，那么`BpBinder`如何标识它所对应的`BBinder`端呢？
答案是`Binder`系统通过`handler`来对应`BBinder`。以后我们会确认这个`Handle`值的作用。

> 注：我们给BpBinder构造函数传的参数handle的值是0。这个0在整个Binder系统中有重要含义—因为0代表的就是ServiceManager所对应的BBinder。

详细看一下`BpBinder`的实现
### 1. BpBinder.cpp

```c
BpBinder::BpBinder(int32_t handle)
    :mHandle(handle)//handle是0
    ,mAlive(1)
    ,mObitsSent(0)
    ,mObituaries(NULL)
{
   extendObjectLifetime(OBJECT_LIFETIME_WEAK);
   //另一个重要对象是IPCThreadState，我们稍后会详细讲解。
   IPCThreadState::self()->incWeakHandle(handle);
}
```
看上面的代码，会觉得`BpBinder`确实简单，不过再仔细查看，你或许会发现，`BpBinder`、`BBinder`这两个类没有任何地方操作`ProcessState`打开的那个`/dev/binder`设备，换言之，**这两个Binder类没有和binder设备直接交互**。那为什么说`BpBinder`会与通信相关呢? 我们接着看`interface_cast（）`函数

我们是从下面这个函数开始分析的：

```c
gDefaultServiceManager =interface_cast<IServiceManager>( ProcessState::self()->getContextObject(NULL));
```
现在这个函数调用将变成如下所示：


```c
gDefaultServiceManager =interface_cast<IServiceManager>(new BpBinder(0));
```
这里出现了一个`interface_cast`。它是什么？其实是一个障眼法！下面就来具体分析它。
### 2. 障眼法——interface_cast
看看`interface_cast`的具体实现，其代码如下所示：


```c
IInterface.h

template<typename INTERFACE>
inline sp<INTERFACE> interface_cast(constsp<IBinder>& obj)
{
    returnINTERFACE::asInterface(obj);
}
哦，仅仅是一个模板函数，所以interface_cast()等价于：

inline sp<IServiceManager>interface_cast(const sp<IBinder>& obj)
{
    return IServiceManager::asInterface(obj);
}

```
又转移到**IServiceManager**对象中去了，还原完模板函数，可以看到`interface_cast（）`实际调用的是`IServiceManager`中的`asInterface()` 方法，该方法传入了上文所说的`BpBinder`对象。看一下`IServiceManager（）`中做了什么操作

### 3. IServiceManager
刚才提到，`IBinder`家族的`BpBinder`和`BBinder`是与通信业务相关的，那么业务层的逻辑又是如何巧妙地架构在`Binder`机制上的呢？关于这些问题，可以用一个绝好的例子来解释，它就是`IServiceManager`。

>【笔记四：】 `IServiceManager`对象其实可以当做java中的接口函数来理解。它定义在`IServiceManager.h` 中，描述了`ServiceManager`可以提供的服务。

#### （1）定义业务逻辑

先回答第一个问题：如何表述应用的业务层逻辑。可以先分析一下`IServiceManager`是怎么做的。IServiceManager定义了`ServiceManager`所提供的服务，看它的定义可知，其中有很多有趣的内容。`IServiceManager`定义在`IServiceManager.h`中，代码如下所示：
**IServiceManager.h**


```c
class IServiceManager : public IInterface
{
 public:
   //关键无比的宏！
   DECLARE_META_INTERFACE(ServiceManager);
 
    //下面是ServiceManager所提供的业务函数
    virtualsp<IBinder>    getService( constString16& name) const = 0;
    virtualsp<IBinder>    checkService( constString16& name) const = 0;
    virtualstatus_t        addService( const String16& name,
                                               const sp<IBinder>&service) = 0;
    virtual Vector<String16>    listServices() = 0;
    ......
};
```
#### （2）业务与通信的挂钩

Android巧妙地通过`DECLARE_META_INTERFACE`和`IMPLENT_META_INTERFACE`宏，将业务和通信牢牢地钩在了一起。`DECLARE_META_INTERFACE`和`IMPLEMENT_META_INTERFACE`这两个宏都定义在刚才的`IInterface.h`中。先看`DECLARE_META_INTERFACE`这个宏，如下所示：
**IInterface.h::DECLARE_META_INTERFACE**


```c
#define DECLARE_META_INTERFACE(INTERFACE)                               \
    staticconst android::String16 descriptor;                          \
    staticandroid::sp<I##INTERFACE> asInterface(                       \
           const android::sp<android::IBinder>& obj);                  \
    virtualconst android::String16& getInterfaceDescriptor() const;    \
   I##INTERFACE();                                                    \
    virtual~I##INTERFACE();   
```
将IServiceManager的`DELCARE`宏进行相应的替换后得到的代码如下所示：
`DECLARE_META_INTERFACE(IServiceManager)`


```c
//定义一个描述字符串
static const android::String16 descriptor;
 
//定义一个asInterface函数
static android::sp< IServiceManager >
asInterface(constandroid::sp<android::IBinder>& obj)
 
//定义一个getInterfaceDescriptor函数，估计就是返回descriptor字符串
virtual const android::String16&getInterfaceDescriptor() const;
 
//定义IServiceManager的构造函数和析构函数
IServiceManager ();                                                   
virtual ~IServiceManager();

```
`DECLARE`宏声明了一些函数和一个变量，那么，`IMPLEMENT`宏的作用肯定就是定义它们了。`IMPLEMENT`的定义在`IInterface.h`中，`IServiceManager`是如何使用了这个宏呢？只有一行代码，在**IServiceManager.cpp**中，如下所示：


```c
IMPLEMENT_META_INTERFACE(ServiceManager,"android.os.IServiceManager");
很简单，可直接将IServiceManager中的IMPLEMENT宏的定义展开，如下所示：

const android::String16
IServiceManager::descriptor(“android.os.IServiceManager”);
//实现getInterfaceDescriptor函数
const android::String16& IServiceManager::getInterfaceDescriptor()const
 { 
    //返回字符串descriptor，值是“android.os.IServiceManager”
      return IServiceManager::descriptor;
  }    
//实现asInterface函数
 android::sp<IServiceManager>
             IServiceManager::asInterface(constandroid::sp<android::IBinder>& obj)
{
       android::sp<IServiceManager> intr;
        if(obj != NULL) {                                              
           intr = static_cast<IServiceManager *>(                         
               obj->queryLocalInterface(IServiceManager::descriptor).get());  
           if (intr == NULL) {
             //obj是我们刚才创建的那个BpBinder(0)
               intr = new BpServiceManager(obj);
            }
        }
       return intr;
}
//实现构造函数和析构函数
IServiceManager::IServiceManager () { }
IServiceManager::~ IServiceManager() { }
```
我们曾提出过疑问：`interface_cast`是如何把`BpBinder`指针转换成一个`IServiceManager`指针的呢？答案就在asInterface函数的一行代码中，如下所示：

`intr = new BpServiceManager(obj);`
明白了！`interface_cast`不是指针的转换，而是利用`BpBinder`对象作为参数新建了一个`BpServiceManager`对象。我们已经知道`BpBinder`和`BBinder`与通信有关系，这里怎么突然冒出来一个`BpServiceManager`？它们之间又有什么关系呢？
### 4 IServiceManager家族

要搞清这个问题，必须先了解`IServiceManager`家族之间的关系，先来看图6-3，它展示了`IServiceManager`的家族图谱。
![](/media/15298420766337.jpg)


图6-3 `IServiceManager`的家族图谱

根据图6-3和相关的代码可知，这里有以下几个重要的点值得注意：

`IServiceManager`、`BpServiceManager`和`BnServiceManager`都与业务逻辑相关。
`BnServiceManager`同时从`BBinder`派生，表示它可以直接参与`Binder`通信。
`BpServiceManager`虽然从`BpInterface`中派生，但是这条分支似乎与`BpBinder`没有关系。
`BnServiceManager`是一个虚类，它的业务函数最终需要子类来实现。
重要说明：以上这些关系很复杂，但`ServiceManager`并没有使用错综复杂的派生关系，它直接打开`Binder`设备并与之交互。后文，还会详细分析它的实现代码。

图6-3中的`BpServiceManager`，既然不像它的兄弟`BnServiceManager`那样直接与`Binder`有血缘关系，那么它又是如何与`Binder`交互的呢？简言之，`BpRefBase`中的`mRemote`的值就是`BpBinder`。如果你不相信，仔细看`BpServiceManager`左边的派生分支树上的一系列代码，它们都在`IServiceManager.cpp`中，如下所示：
**IServiceManager.cpp::BpServiceManager**类

```c
//通过它的参数可得知，impl是IBinder类型，看来与Binder有间接关系,它实际上是BpBinder对象
BpServiceManager(const sp<IBinder>& impl)
   //调用基类BpInterface的构造函数
   : BpInterface<IServiceManager>(impl)
{
}
```
**BpInterface**的实现代码如下所示：

```c
IInterface.h::BpInterface类

template<typename INTERFACE>
inlineBpInterface<INTERFACE>::BpInterface(const sp<IBinder>& remote)
    :BpRefBase(remote)//基类构造函数
{
}
```
`BpRefBase()`的实现代码如下所示：
**Binder.cpp::BpRefBase**类

```
BpRefBase::BpRefBase(const sp<IBinder>&o)
  //mRemote最终等于那个new 出来的BpBinder(0)
    :mRemote(o.get()), mRefs(NULL), mState(0)
{
   extendObjectLifetime(OBJECT_LIFETIME_WEAK);
 
    if(mRemote) {
       mRemote->incStrong(this);          
        mRefs= mRemote->createWeak(this);
    }
}

```

原来，`BpServiceManager`的一个变量`mRemote`是指向了`BpBinder`。回想一下`defaultServiceManager`函数，可以得到以下两个关键对象：

有一个`BpBinder`对象，它的`handle`值是0。
有一个`BpServiceManager`对象，它的`mRemote`值是BpBinder。
> 【笔记五：】在获取`ServiceManager`的时候，通过传入一个`BpBinder（0）`对象，调用到`IServiceManager`的`asInterface()`函数，这个函数创建了一个`BpServiceManger`对象，该对象也是定义在`IServiceManager.cpp` 中的，`BpServiceManager`对象通过构造函数持有了我们传过去的`BpBinder`，并实现了`IServiceManager`的业务函数（其实并没有真正实现，只不过`BpServiceManager`里有一个`IServiceManager`的同名方法，在同名方法里，会将客户端调用该函数的一些参数数据进行封装，打包成`parcel`对象，然后交给自己持有的`BpBinder`，`BpBinder`并不会直接与`binder`驱动进行交互，实际上所有的交互操作都是由`IPCTthreadState`完成的，后文会讲）

## 三、 注册MediaPlayerService
拿到了`BpServiceManager`，其实就可以通过这个代理，与server 也就是`ServiceManager`进行通信了。

现在要想`serviceManager` 注册`MediaPlayerService`服务。我们看一下 代码③ 具体做了什么

**MediaPlayerService.cpp** 

```c
void MediaPlayerService::instantiate() {
    defaultServiceManager()->addService(
           String16("media.player"), new MediaPlayerService());
}
```
根据前面的分析，`defaultServiceManager()`实际返回的对象是`BpServiceManager`，它是`IServiceManager`的后代，代码如下所示：
**IServiceManager.cpp::BpServiceManager**的**addService()**函数


```c
virtual status_t addService(const String16&name, const sp<IBinder>& service)
{
    //Parcel:就把它当作是一个数据包。
    Parceldata, reply;
    data.writeInterfaceToken(IServiceManager::getInterfaceDescriptor());
    data.writeString16(name);
    data.writeStrongBinder(service);
    //remote返回的是mRemote，也就是BpBinder对象
    status_terr = remote()->transact(ADD_SERVICE_TRANSACTION, data, &reply);
    returnerr == NO_ERROR ? reply.readInt32() : err;
}
```
别急着往下走，应先思考以下两个问题：

* 调用`BpServiceManager`的`addService`是不是一个业务层的函数？
* `addService`函数中把请求数据打包成data后，传给了BpBinder的`transact`函数，这是不是把通信的工作交给了`BpBinder`？

两个问题的答案都是肯定的。至此，业务层的工作原理应该是很清晰了，它的作用就是将请求信息打包后，再交给通信层去处理。
通信层的工作
下面分析`BpBinder`的`transact`函数。前面说过，在`BpBinder`中确实找不到任何与Binder设备交互的地方吗？那它是如何参与通信的呢？原来，秘密就在这个`transact`函数中，它的实现代码如下所示：
**BpBinder.cpp**

```c
status_t BpBinder::transact(uint32_t code, constParcel& data, Parcel* reply,
                                 uint32_tflags)
{
    if(mAlive) {
     //BpBinder果然是道具，它把transact工作交给了IPCThreadState
       status_t status = IPCThreadState::self()->transact(
                           mHandle,code, data, reply, flags);//mHandle也是参数
        if(status == DEAD_OBJECT) mAlive = 0;
       return status;
    }
 
    returnDEAD_OBJECT;
}
```
这里又遇见了`IPCThreadState`，之前也见过一次。看来，它确实与`Binder`通信有关，所以必须对其进行深入分析！
### 1 “劳者一份”的IPCThreadState

谁是“劳者”？线程，是进程中真正干活的伙计，所以它正是劳者。而“劳者一份”，就是每个伙计一份的意思。`IPCThreadState`的实现代码在`IPCThreadState.cpp`中，如下所示：
**IPCThreadState.cpp**


```c
IPCThreadState* IPCThreadState::self()
{
    if(gHaveTLS) {//第一次进来为false
restart:
        constpthread_key_t k = gTLS;
 /*
   TLS是Thread Local Storage（线程本地存储空间）的简称。
   这里只需知晓：这种空间每个线程都有，而且线程间不共享这些空间。
   通过pthread_getspecific/pthread_setspecific函数可以获取/设置这些空间中的内容。
   从线程本地存储空间中获得保存在其中的IPCThreadState对象。
   有调用pthread_getspecific的地方，肯定也有调用pthread_setspecific的地方
 */
       IPCThreadState* st = (IPCThreadState*)pthread_getspecific(k);
        if(st) return st;
// new一个对象，构造函数中会调用pthread_setspecific
       return new IPCThreadState;
    }
   
    if(gShutdown) return NULL;
    pthread_mutex_lock(&gTLSMutex);
    if(!gHaveTLS) {
        if(pthread_key_create(&gTLS, threadDestructor) != 0) {
           pthread_mutex_unlock(&gTLSMutex);
           return NULL;
        }
       gHaveTLS = true;
    }
  pthread_mutex_unlock(&gTLSMutex);
//其实goto没有我们说的那么不好，汇编代码也有很多跳转语句（没办法，太低级的语言了），关键是要用好
  goto restart;
}

```
接下来，有必要转向分析它的构造函数IPCThreadState()，如下所示：
**IPCThreadState.cpp**


```c
IPCThreadState::IPCThreadState()
    :mProcess(ProcessState::self()), mMyThreadId(androidGetTid())
{

  //在构造函数中，把自己设置到线程本地存储中去。
   pthread_setspecific(gTLS, this);
    clearCaller();
   //mIn和mOut是两个Parcel。把它看成是发送和接收命令的缓冲区即可。
mIn.setDataCapacity(256);
     mOut.setDataCapacity(256);
}
```
每个线程都有一个`IPCThreadState`，每个`IPCThreadState`中都有一个`mIn`、一个`mOut`，其中mIn是用来接收来自`Binder`设备的数据的，而`mOut`则是用来存储发往`Binder`设备的数据的。
### 2 勤劳的transact

传输工作是很辛苦的。我们刚才看到`BpBinder`的`transact`调用了`IPCThreadState`的`transact`函数，这个函数实际完成了与`Binder`通信的工作，如下面的代码所示：
**IPCThreadState.cpp**


```c
//注意，handle的值为0，代表了通信的目的端
status_t IPCThreadState::transact(int32_t handle,
                                  uint32_tcode, const Parcel& data,
                                  Parcel* reply, uint32_t flags)
{
    status_terr = data.errorCheck();
 
    flags |=TF_ACCEPT_FDS;
 
    ......
/*
【笔记六：】
 注意这里的第一个参数BC_TRANSACTION，它是应用程序向binder设备发送消息的消息码，
 而binder设备向应用程序回复消息的消息码以BR_开头。消息码的定义在binder_module.h中，
 请求消息码和回应消息码的对应关系可见上文驱动篇。这里BC_TRANSACTION对应一次binder事务，client 
 对server的请求	，这里client是服务端，server是serviceManager、
*/
     err =writeTransactionData(BC_TRANSACTION, flags, handle, code, data, NULL);
     ......
     err = waitForResponse(reply);
     ......
   
    returnerr;
}
```
多熟悉的流程：先发数据，然后等结果。再简单不过了！不过，我们有必要确认一下handle这个参数到底起了什么作用。先来看**writeTransactionData**函数，它的实现如下所示：
**IPCThreadState.cpp**


```c
status_tIPCThreadState::writeTransactionData(int32_t cmd, uint32_t binderFlags,
    int32_thandle, uint32_t code, const Parcel& data, status_t* statusBuffer)
{
   //binder_transaction_data 是和binder设备通信的数据结构。   
   binder_transaction_data tr;
 
   //果然，handle的值传递给了target，用来标识目的端，其中0是ServiceManager的标志。
   tr.target.handle= handle;
   //code是消息码，用来switch/case的！
    tr.code =code;
    tr.flags= binderFlags;
   
    conststatus_t err = data.errorCheck();
    if (err== NO_ERROR) {
       tr.data_size = data.ipcDataSize();
       tr.data.ptr.buffer = data.ipcData();
       tr.offsets_size = data.ipcObjectsCount()*sizeof(size_t);
       tr.data.ptr.offsets = data.ipcObjects();
    } else if(statusBuffer) {
       tr.flags |= TF_STATUS_CODE;
       *statusBuffer = err;
       tr.data_size = sizeof(status_t);
       tr.data.ptr.buffer = statusBuffer;
       tr.offsets_size = 0;
       tr.data.ptr.offsets = NULL;
    } else {
       return (mLastError = err);
    }
   //把命令写到mOut中， 而不是直接发出去
      mOut.writeInt32(cmd);
   mOut.write(&tr, sizeof(tr));
    returnNO_ERROR;
}
```
现在，已经把`addService`的请求信息写到`mOut`中了。
> 【笔记七：】
> 注意观察传递数据的变化 在`BpServiceManager`中还是`Parcel`，然后`BpServiceManager` 交给了`BpBinder`，`BpBinder`又把数据交给了`IPCThreadState`， `IPCThreadState`调用`writeTransactionData`方法，将数据进一步封装为 `binder_transaction_data`，并将`binder_transaction_data`和`BC_XXX`指令写到`IPCThreadState`中的`mOut`中。

·
> 【笔记八：】可以看到 真正与`binder驱动打`驱动打交道的是`IPCThreadState`。与`Binder`驱动打交道，意味着要往`binder`驱动写指令和数据，同时要从`binder`驱动读取返回的结果。`writeTranscationData()`方法实际上并没有做 往`binder`里写数据的操作，而是把数据写到自己的`mOut`成员变量里，那这个成员变量是怎么传给binder驱动的呢？ 其实是在`waitForResponse（）`函数里，`waitForResponse()`中的`talkWithDriver()`会读取`mOut`的数据并将数据传递给`binder`驱动，然后从`binder`驱动中读取返回数据传递给`mIn`，这样就完成了一次数据交互。


接下来再看发送请求和接收回复部分的实现，代码在`waitForResponse`函数中，如下所示：
**IPCThreadState.cpp**

```c
status_t IPCThreadState::waitForResponse(Parcel*reply, status_t *acquireResult)
{
    int32_tcmd;
    int32_terr;
 
while (1) {
        //talkWithDriver 在这里才真正开始与驱动打交道
        if((err=talkWithDriver()) < NO_ERROR) break;
        err =mIn.errorCheck();
        if(err < NO_ERROR) break;
        if(mIn.dataAvail() == 0) continue;
       
        cmd =mIn.readInt32();
       switch(cmd) {
        caseBR_TRANSACTION_COMPLETE:
           if (!reply && !acquireResult) goto finish;
           break;
        ......
        default:
           err = executeCommand(cmd);//看这个！
           if (err != NO_ERROR) goto finish;
           break;
        }
    }
 
finish:
    if (err!= NO_ERROR) {
        if(acquireResult) *acquireResult = err;
        if(reply) reply->setError(err);
       mLastError = err;
    }
   
    returnerr;
}
```
接下来看看`talkWithDriver()`函数

### 3 talkWithDriver（）
talkwithDriver函数，如下所示：
**IPCThreadState.cpp**


```c
status_t IPCThreadState::talkWithDriver(bool doReceive)
{
  // binder_write_read是用来与Binder设备交换数据的结构
    binder_write_read bwr;
    constbool needRead = mIn.dataPosition() >= mIn.dataSize();
    constsize_t outAvail = (!doReceive || needRead) ? mOut.dataSize() : 0;
   
    //【笔记9】
   bwr.write_size = outAvail;
   bwr.write_buffer = (long unsigned int)mOut.data();
 
  if(doReceive && needRead) {
       //接收数据缓冲区信息的填充。如果以后收到数据，就直接填在mIn中了。
       bwr.read_size = mIn.dataCapacity();
       bwr.read_buffer = (long unsigned int)mIn.data();
    } else {
       bwr.read_size = 0;
    }
   
    if((bwr.write_size == 0) && (bwr.read_size == 0)) return NO_ERROR;
   
   bwr.write_consumed = 0;
   bwr.read_consumed = 0;
    status_terr;
    do {
  #ifdefined(HAVE_ANDROID_OS)
        //看来不是read/write调用，而是ioctl方式。
        if(ioctl(mProcess->mDriverFD, BINDER_WRITE_READ, &bwr) >= 0)
           err = NO_ERROR;
        else
           err = -errno;
#else
        err =INVALID_OPERATION;
#endif
       }while (err == -EINTR);
   
     if (err>= NO_ERROR) {
        if(bwr.write_consumed > 0) {
           if (bwr.write_consumed < (ssize_t)mOut.dataSize())
               mOut.remove(0, bwr.write_consumed);
           else
               mOut.setDataSize(0);
        }
        if(bwr.read_consumed > 0) {
           mIn.setDataSize(bwr.read_consumed);
           mIn.setDataPosition(0);
        }
       return NO_ERROR;
    }
    returnerr;
}
```

![](/media/15298933056244.jpg)
图 `binder_write_read`结构体

> 【笔记九：】`waitForResponse（）`是直接参与与`binder`驱动交互的地方了，首先 它初始化了`binder_read_write`结构体，将`mIn`和`mOut`中的数据读出来（如果有的话，没有就相当于初始化了），继而调用了`binder`驱动的ioctrl（）方法（对应驱动层的`binder_ioctrl()`），将这个封装好的`binder_read_write`结构发送给`binder`驱动，还记得上文`binder`驱动篇中的分析吗，binder驱动的`binder_ioctrl`()逻辑很简单，只是取出BC码和BR码，然后根据码来做对应的操作。
> **这里综述一下framework到驱动层之间的通讯流程，具体如下**
> 1.**ProcessState::self 打开驱动：**`binder`驱动会为每一个`flat_binder_object`对象在内核中创建一个唯一的`BinderNode`与之对应。 同时，每一个打开了`binder`驱动的进程，在内核中都有一个`binder_proc`结构体与之对应，该结构体被加载在`binder_procs`的全局链表上，是全局链表，所以这何一个进程（我们这里是`MediaServer`）都可以访问到任何进程的`binder_proc`对象了。同时，`binder_node` 被加载在`binder_proc`的`nodes`红黑树中。
> .
> .
> 2.**mmap()让binder驱动去申请空间并做地址映射：**还记得我们`MediaServer`初始化的时候调用了一个`ProcessState::self` 方法吗，它除了打开驱动，还调用了`mmap()`为该进程分配一个buffer，默认是4k ，也就是一个页面，这可以从分配函数看出来

```c
binder_update_page_range(proc, 1, proc->buffer, proc->buffer + PAGE_SIZE, vma)；
```
> `PAGE_SIZE = 4K`，分配完成后 以`binder_buffer` 的形式 保存在`proc`的`buffers`红黑数里，同时进行了用户空间和内核空间的物理地址映射，也就是说现在`mediaserver`和内核空间映射了同一份物理地址，`server`端可以直接访问该物理地址而不需要将数据从内核空间往`server`进程所在的用户空间再拷贝一次了！
>.
>.
> 3. **通过ProcessState的getStrongProxyForHandle方法，创建了一个客户端“信使”BpBinder（0）**，其中`handle = 0 `，驱动其实正是通过handle值来查找客户端要通信的对端对应的`binderNode`，这个后面会说。该信使还持有`IPCThreadState`对象，它才是真正负责与驱动通讯的。
>.
>.
>4.**创建服务端**（这里是`serviceManager`做特殊的服务端，它提供的服务是注册服务`add_service`方法）**对应的BpServiceManager对象**（`BpServiceManager`对象，它是`IServiceManager`的儿子，`IServiceManager`定义了业务函数和`interface_cast`转换函数，同时继承了`BpBinderInterface`接口,我们创建服务端的`BpServiceManager`，其实就是调用了`IServiceManager.cpp`中的`asInterface`函数，创建了一个`BpServiceManager`，同时它还持有我们传进去的信使“`BpBinder（0）`“的引用，对应`mRemote`）。现在我们有`BpServiceManager`了，它也有`IserviceMaganer`的业务函数，当我们调用对应的业务函数，这里是add_service（）要将我们的服务注册上去时，它会把命令交给`mRemote`，也就是我们的`BpBinder().transact()`方法，`transact（）`会调用`IPCThreadState`的`transact（）`方法。
>.
>.
>5. **IPCThreadState.transact(int32_t handle,uint32_t,code, const Parcel& data,Parcel* reply, uint32_t flags)与驱动交流，先写后读。**
>.
>.
>6. **将请求内容写到写缓冲区mOut**，通过`IPCThreadState::self.writeTransactionData` 吧数据封装成`binder_transaction_data`
>.
>.
>7. **把请求内容发送给驱动，并等待驱动返回结果，将结果写在mIn缓冲区**，读写是通过`IPCThreadState`的`talkWithDriver()`方法，该方法进一步封装了要传递给`binder`驱动的数据，变为binder_read_write，同时把写的数据填入`write_buffer`里了。在`talkWithDriver`中，通过系统调用`ioctl(mProcess->mDriverFD, BINDER_WRITE_READ, &bwr)`将数据发送给驱动。注意，现在`bwr`中的指令是`BC_TRANSACATION` ，并且`wirte_size>0`,且`write_buffer`不为空。
> .
> .
> 8. **binder_proc对象，再看一下这张图复习一下**
![](/media/15298989934622.jpg)
> `binder_proc`除了图中所画的几个成员之外，还有两个重要成员，都会在创建binder_proc对象的时候一起初始化。分别是
> **struct list_head todo：**当进程接收到一个进程间通信请求时，Binder驱动就将该请求封装成一个工作项，并且加入到进程的待处理工作向队列中，该队列使用成员变量`todo`来描述。
**wait_queue_head_t wait：** 线程池中空闲Binder线程会睡眠在由该成员所描述的等待队列中， 当宿主进程的待处理工作项队列增加新工作项后，驱动会唤醒这些线程，以便处理新的工作项。
 后面会讲到`binder`驱动会用他们来构建`binder_transaction` 结构体。
 
> 以我们的例子为例，`MediaServer` 调用`IPCTtreadState`，并将mOut通过`waitForResponse()`里的`ioctrl(BINDER_READ_WRITE,&data)`发送给驱动的时候，驱动早已经完成步骤1、2了。也就是`MediaServer` 已经有了一个对应的`binder_proc` 结构体，而且其携带的的`flat_binder_object`的`handle`指向0.注意，这里面的`flat_handle_object`中的`type`是`handle`，同时`handle = 0`；【注： 见上文 [5.通讯过程中的binder实体的传递](http://wenyiqingnian.xyz/2018/06/02/%E4%BB%8E%E9%A9%B1%E5%8A%A8%E8%A7%92%E5%BA%A6%E7%90%86%E8%A7%A3binder/)】并且做了地址映射。
.
.
> 9.**调用驱动的ioctrl()方法发送BINDER_WRITE_READ**， 在`ioctrl`()函数的入口处，会执行 `thread = binder_get_thread(proc)`，该函数首先获取打开驱动的进程的`pid`号，根据pid号，检查是否可以在`threads`的红黑树中找到对应的`thread`对象，有就直接返回，没有就创建对应的`Thread`对象，加入`binder_proc`的`threads`的红黑树中。
> .
> .
> 10.现在binder驱动已经有了线程的`Thread`对象，并加入到`binder_proc`中的`threads`红黑树中。并且知道了请求码是`BINDER_WRITE_READ`，驱动篇讲过，`ioctrl`的功能就是根据不同请求码调用不同的处理方法。如果命令是`BINDER_WRITE_READ`，并且 `bwr.write_size > 0`，则调用`binder_thread_write`。

```c
switch (cmd) {
	case BINDER_WRITE_READ: {
		struct binder_write_read bwr;
        ...
		if (bwr.write_size > 0) {
			ret = binder_thread_write(proc, thread, (void __user *)bwr.write_buffer, bwr.write_size, &bwr.write_consumed);
			trace_binder_write_done(ret);
			if (ret < 0) {
				bwr.read_consumed = 0;
				if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
					ret = -EFAULT;
				goto err;
			}
		}
		if (bwr.read_size > 0) {
			ret = binder_thread_read(proc, thread, (void __user *)bwr.read_buffer, bwr.read_size, &bwr.read_consumed, filp->f_flags & O_NONBLOCK);
			trace_binder_read_done(ret);
			if (!list_empty(&proc->todo))
				wake_up_interruptible(&proc->wait);
			if (ret < 0) {
				if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
					ret = -EFAULT;
				goto err;
			}
		}
```
> 当`write_buffer`存在数据，`binder`线程的写操作循环执行。这里`bwr.write_size>0`,故会执行写循环，也就是binder_thread_write()方法。
> .
> .
> 11.**进入binder_thread_write()来处理请求码**。首先读取Binder命令，由于buffer里只是指向命令的指针，实际数据还保存在用户空间，因此调用get_user函数从用户空间读取数据（一次拷贝）。取得命令后，先更新命令的状态信息，然后根据不同命令 进行不同的处理。这里的例子中，`MediaServer`发送的命令是`BC_TRANSACTION`，对于请求码为`BC_TRANSACTION`或`BC_REPLY`时，会执行`binder_transaction()`方法，这是最为频繁的操作。 

```c
int binder_thread_write(struct binder_proc *proc, struct binder_thread *thread,
			void __user *buffer, int size, signed long *consumed)
{
	uint32_t cmd;
	void __user *ptr = buffer + *consumed;
	void __user *end = buffer + size;
	...
		switch (cmd) {
		case BC_TRANSACTION:
		case BC_REPLY: {
			struct binder_transaction_data tr;

			if (copy_from_user(&tr, ptr, sizeof(tr)))
				return -EFAULT;
			ptr += sizeof(tr);
			// 【笔记十：】注意看最后一个参数，因为BC_TRANSACTION 还有BC_REPLY 都会
			//调用binder_transaction()，一个函数处理了两个逻辑，所有它用了一个boolean值 
		   //cmd == BC_REPLAY 来决定走哪个流程
			binder_transaction(proc, thread, &tr, cmd == BC_REPLY);
			break;
		}
```
>.
>.
>12.**binder_transaction内部流程**

 * 首先梳理下当前传进来的`binder_transaction_data`到底包含了哪些数据：
 
 ![](/media/15299308632940.png)
 

 * 1 根据`binder_transaction_data` 中的`handle`,通过映射关系![](/media/15299136178694.jpg)
找到对应的`binder_node`，进而找到目标进程`binder_proc`

* 2 根据本次`binder_transaction`是否是异步，如果不是异步，意味着当前的`binder`传输流程还没走完，还是同一个`transaction`流程，从`from_parent`查找，如果是异步，从`binder_proc` 回溯查找`target_thread`。 
* 3 如果找到`target_thread`，则它就是目标线程，否则`binder_proc`对应的进程是目标线程。
* 4 根据用户空间传入的数据和目标，发起事务的线程、进程信息，创建`binder_transaction`结构体，`binder_transaction` 其实与一次`binder_transaction（）`方法对应的，每执行一次，便会在驱动中为其创建一个对应的结构体。这里要解释一下什么是`binder_transaction`对象。可以这么理解，`binder_transaction_data`是`binder`传输对象的外部表示，应用于应用程序的，而`binder_transaction`是`binder`传输对象的内部表示，应用于内核binder驱动本身。`binder_transaction`对象都位于`binder_thread`的传输栈上，其本身是一个多级链表结构，描述了传输来源和传输目标，也记录了本次传输的信息，如`binder_work`、`binder_buffer`、`binder`命令等。


```c
struct binder_transaction {
    int debug_id;
    // 当驱动为目标进程或线程创建一个事务时，就会将该成员的type置为
    // BINDER_WORK_TRANSACTION，并将它添加到目标进程或线程的todo队列，等待处理
    struct binder_work work;
    struct binder_thread *from;         // 发起事务的线程
    // 事务所依赖的另外一个事务以及目标线程下一个要处理的事务
    struct binder_transaction *from_parent; 
    struct binder_proc *to_proc;        // 负责处理该事务的进程
    struct binder_thread *to_thread;    // 负责处理该事务的线程
    struct binder_transaction *to_parent;
    unsigned need_reply:1;              // 同步事务为1需要等待对方回复；异步为0
    /* unsigned is_dead:1; */   /* not used at the moment */
    // 指向驱动为该事务分配的内核缓冲区，保存了进程间通信数据
    struct binder_buffer *buffer;   
    unsigned int    code;   // 直接从进程间通信数据中拷贝过来
    unsigned int    flags;  // 直接从进程间通信数据中拷贝过来
    long    priority;       // 源线程优先级
    // 线程在处理事务时，驱动会修改它的优先级以满足源线程和目标Service组建的要求。在修改之
    // 前，会将它原来的线程优先级保存在该成员中，以便线程处理完该事务后可以恢复原来的优先级
    long    saved_priority; 
    uid_t   sender_euid;    // 源线程用户ID
};
```



* 4 根据传输的目标设置本次`binder`传输的目标等待队列(`wait_queue`)和本次`binder_work`需要挂载的列表(`list`)，也就是`target_wait`和`target_list`。其中`target_wait`中存放的就是本次要唤醒的目标进程/线程。 `target_list` 就是目标进程中的`todo`
* 5 到目前，`target_node`，`target_thread`，`target_proc`，`target_wait`和`target_list`都已经找到了。下面就该为此次传输分配新的`binder_transaction`对象和`binder_work`对象了，并根据当前的信息填充内容
* 6 构造一个新的`binder_transaction` 对象，并为期分配内存，同时修改`flat_binder_object`,做好`handle`到`binder`地址之间的映射。如果发送端发的是`binder`，驱动会把`type` 修改为`HANDLE_TYPE`，同时找到`binder_node->binder_ref` 找到索引id，`binder_ref->desc`，将改id赋值给`handle`.如果是`handle`，吧流程返过来，`handle->binder_ref->binder_node`，将`binder_node` 赋值给`flat_binder_object`中的`binder`，修改`type`为`BINDER_TYPE`；
* 7 新的`binder_flat_object`修改好了，在此之前，还要根据是同步传输还是异步传输，设置`binder_transaction`中的`replay`值，并将`binder_transaction`插入到`target_list`也即`traget_tread`/`target_proc`的`todo`队列中。

至此 发送命令算是做完了。可以看到，调用了`binder_transcation`之后，并没有把数据发送给`server`，驱动只不过是创建了一个`binder_transaction`结构，然后把它挂在`binder_proc`的`todo`队列中。
![](/media/15299341943387.png)
图：驱动层调用层级

![](/media/15299348916454.jpg)

> **总结： 客户端的每一次请求，驱动最终都会生成换一个binder_transaction结构体，并把这个结构体挂在目标进程target_proc 也就是Server端 ServerManager服务对应的那个binder_proc 中。**

* 8 唤醒等待线程的目标线程

```c
if (target_wait)  
    wake_up_interruptible(target_wait);  
```

* 9 server端的目标线程开始进入`binder_loop`状态，从`ServiceManager`那端来看，它走的其实和client端发起请求的流程是类似的，只不过此时`mOut`为空，binder驱动执行`binder_thread_read`()方法。
* 10 server端通过`ioctrl`控制驱动执行`binder_thread_read`,首先读取`todo`列表的首节点。这是client端发送请求操作完成之后插进来的。
* 11 根据todo中的`binder_work` 找到对应的`binder_transaction`,有了`binder_transaction`,便从`binder_transaction` 和`binder_buffer`中提取出`client`端发送的数据，重新组装成`binder_transaction_data`。
* 12 将`binder_transaction_data`结构体通过`copy_to_user`拷贝到用户空间，由接收端`ServiceManager`收到

* 13 server端收到binder驱动转发的客户端数据 进行处理后，再发送回给binder驱动。一次循环往复。完成客户端往服务端发送数据的过程。
> 总结：客户端的请求，都会被binder驱动创建一个对应的binder_transaction。并将这个transaction挂在目标进程binder_proc的todo链表里，binder驱动再唤醒目标进程，目标进程对驱动执行读取命令，驱动执行binder_thread_read，同时将客户端发送的数据，以查找todo链表 -> 查找binder_transaction-> binder_buffer 的方式，重新包装成binder_transaction_data，拷贝到server端对应的用户空间。同时将改todo列表删除。至此完成客户端->server端的传输。server的返回数据流程和这个基本一致，只不过server和client的角色需要对调一下。


OK，我们已发送了请求数据，假设马上就收到了回复，后续该怎么处理呢？来看executeCommand函数，如下所示：
**IPCThreadState.cpp**



```c
status_t IPCThreadState::executeCommand(int32_tcmd)
{
    BBinder*obj;
   RefBase::weakref_type* refs;
    status_tresult = NO_ERROR;
   
    switch(cmd) {
    caseBR_ERROR:
       result = mIn.readInt32();
       break;
        ......
     caseBR_TRANSACTION:
        {
           binder_transaction_data tr;
           result = mIn.read(&tr, sizeof(tr));
           if (result != NO_ERROR) break;
            Parcel buffer;
           Parcel reply;
           if (tr.target.ptr) {
           /*
             看到了BBinder，想起图6-3了吗？BnServiceXXX从BBinder派生，
             这里的b实际上就是实现BnServiceXXX的那个对象，关于它的作用，后文会详述              
             */
                sp<BBinder> b((BBinder*)tr.cookie);
               const status_t error = b->transact(tr.code, buffer, &reply, 0);
                if (error < NO_ERROR)reply.setError(error);
             } else {
          /*
           the_context_object是IPCThreadState.cpp中定义的一个全局变量，
           可通过setTheContextObject函数设置
           */
               const status_t error =
                             the_context_object->transact(tr.code,buffer, &reply, 0);
               if (error < NO_ERROR) reply.setError(error);
         }
       break;
    ......
    case BR_DEAD_BINDER:
        {
         /*
           收到binder驱动发来的service死掉的消息，看来只有Bp端能收到了，
           后面，我们将会对此进行分析。
         */
           BpBinder *proxy = (BpBinder*)mIn.readInt32();
           proxy->sendObituary();
           mOut.writeInt32(BC_DEAD_BINDER_DONE);
           mOut.writeInt32((int32_t)proxy);
        }break;
        ......
case BR_SPAWN_LOOPER:
  //特别注意，这里将收到来自驱动的指示以创建一个新线程，用于和Binder通信。
       mProcess->spawnPooledThread(false);
       break;
      default:
        result = UNKNOWN_ERROR;
       break;
    }
   ......
    if(result != NO_ERROR) {
       mLastError = result;
    }
    returnresult;
}
```


## 4 StartThread Pool和join Thread Pool
### 1.创造劳动力——startThreadPool()
`startThreadPool()`的实现，如下面的代码所示：
**ProcessState.cpp**
//太简单，没什么好说的

```c
void ProcessState::startThreadPool()
{
AutoMutex _l(mLock);
//如果要是已经startThreadPool的话，这个函数就没有什么实质作用了
    if(!mThreadPoolStarted) {
       mThreadPoolStarted = true;
       spawnPooledThread(true); //注意，传进去的参数是true
    }
}
上面的spawnPooledThread()函数的实现，如下所示：
ProcessState.cpp

void ProcessState::spawnPooledThread(bool isMain)
{
  //注意，isMain参数是true。
    if(mThreadPoolStarted) {
       int32_t s = android_atomic_add(1, &mThreadPoolSeq);
        char buf[32];
       sprintf(buf, "Binder Thread #%d", s);
        sp<Thread> t = new PoolThread(isMain);
       t->run(buf);
    }
}
```
PoolThread是在IPCThreadState中定义的一个Thread子类，它的实现，如下所示：
**IPCThreadState.h::PoolThread**类


```c
class PoolThread : public Thread
{
public:
   PoolThread(bool isMain)
        :mIsMain(isMain){}
   protected:
    virtualbool threadLoop()
    {
       //线程函数如此简单，不过是在这个新线程中又创建了一个IPCThreadState。
      // 你还记得它是每个伙计都有一个的吗？
        IPCThreadState::self()->joinThreadPool(mIsMain);
        return false;
    }
   const boolmIsMain;
};

```
### 2万众归一  joinThreadPool
还需要看看`IPCThreadState`的`joinThreadPool`的实现，因为新创建的线程也会调用这个函数，具体代码如下所示：
**IPCThreadState.cpp**

```c
void IPCThreadState::joinThreadPool(bool isMain)
{
   //注意，如果isMain为true，我们需要循环处理。把请求信息写到mOut中，待会儿一起发出去
   mOut.writeInt32(isMain ? BC_ENTER_LOOPER : BC_REGISTER_LOOPER);
   
  androidSetThreadSchedulingGroup(mMyThreadId, ANDROID_TGROUP_DEFAULT);
       
    status_tresult;
    do {
       int32_t cmd;
       
        if(mIn.dataPosition() >= mIn.dataSize()) {
           size_t numPending = mPendingWeakDerefs.size();
           if (numPending > 0) {
               for (size_t i = 0; i < numPending; i++) {
                   RefBase::weakref_type* refs = mPendingWeakDerefs[i];
                    refs->decWeak(mProcess.get());
               }
               mPendingWeakDerefs.clear();
            }
           //处理已经死亡的BBinder对象
           numPending = mPendingStrongDerefs.size();
           if (numPending > 0) {
               for (size_t i = 0; i < numPending; i++) {
                   BBinder* obj = mPendingStrongDerefs[i];
                   obj->decStrong(mProcess.get());
               }
               mPendingStrongDerefs.clear();
            }
        }
        // 发送命令，读取请求
       result = talkWithDriver();
        if(result >= NO_ERROR) {
           size_t IN = mIn.dataAvail();
            if (IN < sizeof(int32_t)) continue;
           cmd = mIn.readInt32();
            result= executeCommand(cmd); //处理消息
        }
       
        ......
    } while(result != -ECONNREFUSED && result != -EBADF);
 
   mOut.writeInt32(BC_EXIT_LOOPER);
   talkWithDriver(false);
}
```

原来，我们的两个伙计在`talkWithDriver`，它们希望能从`Binder`设备那里找到点可做的事情。
### 3. 有几个线程在服务
到底有多少个线程在为Service服务呢？目前看来是两个：

`startThreadPool`中新启动的线程通过`joinThreadPool`读取Binder设备，查看是否有请求。
主线程也调用`joinThreadPool`读取Binder设备，查看是否有请求。看来，binder设备是支持多线程操作的，其中一定是做了同步方面的工作。
`mediaserver`这个进程一共注册了4个服务，繁忙的时候，两个线程会不会显得有点少呢？另外，如果实现的服务负担不是很重，完全可以不调用startThreadPool创建新的线程，使用主线程即可胜任。

# 特殊的server端，ServiceManager
刚才分析的`MediaServer`，在跟`servicemanager`注册服务的时候，其实扮演的是client的角色。
`serviceManager` 是系统所有服务的大管家，提供查询，注册服务等方法。
## 1. serviceManager 原理
前面说过，`defaultServiceManager`返回的是一个`BpServiceManager`，通过它可以把命令请求发送给handle值为0的目的端。按照图6-3所示的`IServiceManager`“家谱”，无论如何也应该有一个类从`BnServiceManager`派生出来并处理这些来自远方的请求吧？
很可惜，源码中竟然没有这样的一个类存在！但确实又有这么一个程序完成了`BnServiceManager`未尽的工作，这个程序就是`servicemanager`，它的代码在**Service_manager.c**中，如下所示：

注意：通过这件事情是否能感悟到什么？嗯，我们确实可以抛开前面所有的那些封装，直接与Binder设备打交道。

下面来看`ServiceManager`是怎么放弃华丽的封装去做Manager的。

### 1 ServiceManager的入口函数
ServiceManager的入口函数如下所示。
**ServiceManager.c**

```c
int main(int argc, char **argv)
{
   structbinder_state *bs;
   //BINDER_SERVICE_MANAGER的值为NULL，是一个magic number。
   void*svcmgr = BINDER_SERVICE_MANAGER;
   //①应该是打开binder设备吧？
   bs = binder_open(128*1024);
   //②成为manager，是不是把自己的handle置为0？
   binder_become_context_manager(bs)
   svcmgr_handle= svcmgr;
   //③处理客户端发过来的请求。
   binder_loop(bs, svcmgr_handler);
}
```

这里，一共有三个重要关键点。必须对其逐一地进行分析。

注意：有一些函数是在**Binder.c**中实现的，此**Binder.c**不是前面碰到的那个**Binder.cpp**。

### 2 打开Binder设备
`binder_open`函数用于打开Binder设备，它的实现如下所示：
**Binder.c**

```c
/*
  这里的binder_open应该与我们之前在ProcessState中看到的一样：
  1）打开Binder设备
  2）内存映射
*/
struct binder_state *binder_open(unsigned mapsize)
{
    structbinder_state *bs;
    bs =malloc(sizeof(*bs));
    ....
    bs->fd= open("/dev/binder", O_RDWR);
    ....
   bs->mapsize = mapsize;
   bs->mapped = mmap(NULL, mapsize, PROT_READ, MAP_PRIVATE, bs->fd,0);
  }
```
果然如此，有了之前所学习掌握的知识，这里真的就不难理解了。
### 3. 成为老大
怎么才成为系统中独一无二的manager了呢？manger的实现，如下面的代码所示：
**Binder.c**


```c
int binder_become_context_manager(structbinder_state *bs)
{
   //实现太简单了！这个0是否就是设置自己的handle呢？
    returnioctl(bs->fd, BINDER_SET_CONTEXT_MGR, 0);
}
```
### 4.死磕Binder
`binder_loop`是一个很尽责的函数。为什么这么说呢？因为它老是围绕着Binder设备转悠，实现代码如下所示：
**Binder.c**

```c
/*
  注意binder_handler参数，它是一个函数指针，binder_loop读取请求后将解析
  这些请求，最后调用binder_handler完成最终的处理。
*/
void binder_loop(struct binder_state *bs,binder_handler func)
{
    int res;
    structbinder_write_read bwr;
   readbuf[0] = BC_ENTER_LOOPER;
   binder_write(bs, readbuf, sizeof(unsigned));
    for (;;){//果然是循环
       bwr.read_size = sizeof(readbuf);
       bwr.read_consumed = 0;
       bwr.read_buffer = (unsigned) readbuf;
 
        res =ioctl(bs->fd, BINDER_WRITE_READ, &bwr);
        //接收到请求，交给binder_parse，最终会调用func来处理这些请求。
        res = binder_parse(bs, 0, readbuf,bwr.read_consumed, func);
  }
```
### 5 集中处理
往`binder_loop`中传的那个函数指针是svcmgr_handler，它的代码如下所示：
**Service_manager.c**

```c
int svcmgr_handler(struct binder_state *bs,structbinder_txn *txn,
                      struct binder_io *msg,structbinder_io *reply)
{
    structsvcinfo *si;
    uint16_t*s;
    unsignedlen;
    void*ptr;
    // svcmgr_handle就是前面说的那个magic number，值为NULL。
   //这里要比较target是不是自己。
    if(txn->target != svcmgr_handle)
       return -1;
    s =bio_get_string16(msg, &len);
 
    if ((len!= (sizeof(svcmgr_id) / 2)) ||
       memcmp(svcmgr_id, s, sizeof(svcmgr_id))) {
       return-1;
    }
 
   switch(txn->code) {
    caseSVC_MGR_GET_SERVICE://得到某个service的信息，service用字符串表示。
    caseSVC_MGR_CHECK_SERVICE:
        s = bio_get_string16(msg, &len);//s是字符串表示的service名称。
        ptr =do_find_service(bs, s, len);
        if(!ptr)
           break;
       bio_put_ref(reply, ptr);
       return 0;
    caseSVC_MGR_ADD_SERVICE://对应addService请求
        s =bio_get_string16(msg, &len);
        ptr =bio_get_ref(msg);
        if(do_add_service(bs, s, len, ptr, txn->sender_euid))
           return -1;
       break;
    //得到当前系统已经注册的所有service的名字。
    caseSVC_MGR_LIST_SERVICES: {
       unsigned n = bio_get_uint32(msg);
        si =svclist;
        while((n-- > 0) && si)
           si = si->next;
        if(si) {
           bio_put_string16(reply, si->name);
           return 0;
        }
       return -1;
    }
    default:
       return-1;
    }
    bio_put_uint32(reply,0);
    return 0;
}
```

## 2 服务的注册
上面提到的`switch/case`语句，将实现`IServiceManager`中定义的各个业务函数，我们重点看`do_add_service`这个函数，它最终完成了对`addService`请求的处理实现，代码如下所示：
**Service_manager.c**


```c
int do_add_service(struct binder_state *bs,uint16_t*s, unsigned len,
                       void*ptr, unsigned uid)
{
    structsvcinfo *si;
    if (!ptr|| (len == 0) || (len > 127))
       return -1;
     //svc_can_register函数比较注册进程的uid和名字。
    if(!svc_can_register(uid, s)) {
       return -1;
    ......

```
将上面的函数暂时放一下，先介绍`svc_can_register`函数。

### 1不是什么都可以注册的
`do_add_service`函数中的`svc_can_register`，是用来判断注册服务的进程是否有权限的，代码如下所示：
**Service_manager.c**

```c
int svc_can_register(unsigned uid, uint16_t *name)
{
    unsignedn;
    //如果用户组是root用户或者system用户，则权限够高，允许注册
    if ((uid== 0) || (uid == AID_SYSTEM))
       return 1;
 
    for (n =0; n < sizeof(allowed) / sizeof(allowed[0]); n++)
        if((uid == allowed[n].uid) && str16eq(name, allowed[n].name))
           return 1;
 
    return 0;
}

```
`allowed`结构数组，控制那些权限达不到root和system的进程，它的定义如下所示：


```c
static struct {
    unsigneduid;
    constchar *name;
} allowed[] = {
#ifdef LVMX
    {AID_MEDIA, "com.lifevibes.mx.ipc" },
#endif
    {AID_MEDIA, "media.audio_flinger" },
    {AID_MEDIA, "media.player" },
    {AID_MEDIA, "media.camera" },
    {AID_MEDIA, "media.audio_policy" },
    {AID_RADIO, "radio.phone" },
    {AID_RADIO, "radio.sms" },
    {AID_RADIO, "radio.phonesubinfo" },
    {AID_RADIO, "radio.simphonebook" },
    {AID_RADIO, "phone" },
    {AID_RADIO, "isms" },
    {AID_RADIO, "iphonesubinfo" },
    {AID_RADIO, "simphonebook" },
};

```
所以，如果Server进程权限不够root和system，那么请记住要在`allowed`中添加相应的项。
### 2. 添加服务项
再回到我们的`do_add_service`，如下所示：
**Service_manager.c**

```c
int do_add_service(struct binder_state *bs,uint16_t*s, unsigned len,
                      void *ptr, unsigned uid){
 
...... //接前面的代码
    si =find_svc(s, len);
    if (si) {
        if(si->ptr) {
           return -1;
        }
       si->ptr = ptr;
    } else {
        si =malloc(sizeof(*si) + (len + 1) * sizeof(uint16_t));
        if(!si) {
            return -1;
        }
        //ptr是关键数据，可惜为void*类型。只有分析驱动的实现才能知道它的真实含义了。
       si->ptr = ptr;
       si->len = len;
       memcpy(si->name, s, (len + 1) * sizeof(uint16_t));
       si->name[len] = '\0';
       si->death.func = svcinfo_death;//service退出的通知函数
       si->death.ptr = si;
        //这个svclist是一个list，保存了当前注册到ServiceManager中的信息。
       si->next = svclist;
       svclist = si;
    }
 
   binder_acquire(bs,ptr);
  /*
我们希望当服务进程退出后，ServiceManager能有机会做一些清理工作，例如释放前面malloc出来的si。
binder_link_to_death完成这项工作，每当有服务进程退出时，ServiceManager都会得到来自
Binder设备的通知。
*/
   binder_link_to_death(bs, ptr, &si->death);
    return 0;
}

```
至此，服务注册分析完毕。可以知道，`ServiceManager`不过就是保存了一些服务的信息。那么，这样做又有什么意义呢？

* `ServiceManger`能集中管理系统内的所有服务，它能施加权限控制，并不是任何进程都能注册服务。
* `ServiceManager`支持通过字符串名称来查找对应的Service。这个功能很像DNS。
* 由于各种原因，Server进程可能生死无常。如果让每个Client都去检测，压力实在太大。现在有了统一的管理机构，Client只需要查询`ServiceManager`，就能把握动向，得到最新信息。这可能正是`ServiceManager`存在的最大意义吧。

# MediaPlayerService和它的Client
前面，一直在讨论`ServiceManager`和它的`Client`，现在我们以`MediaPlayerService`的`Client`换换口味吧。由于`ServiceManager`不是从`BnServiceManager`中派生的，所以之前没有讲述请求数据是如何从通讯层传递到业务层来处理的过程。本节，我们以`MediaPlayerService`和它的`Client`做为分析对象，试解决这些遗留问题。

## 查询ServiceManager

前文曾分析过`ServiceManager`的作用，一个Client想要得到某个Service的信息，就必须先和`ServiceManager`打交道，通过调用`getService`函数来获取对应Service的信息。请看来源于**IMediaDeathNotifier.cpp**中的例子`getMediaPlayerService()`，它的代码如下所示：
**IMediaDeathNotifier.cpp**


```c
/*
  这个函数通过与ServiceManager通信，获得一个能够与MediaPlayerService通信的BpBinder，
  然后再通过障眼法interface_cast，转换成一个BpMediaPlayerService。
*/
IMediaDeathNotifier::getMediaPlayerService()
{
       sp<IServiceManager> sm = defaultServiceManager();
       sp<IBinder> binder;
        do {
       //向ServiceManager查询对应服务的信息，返回BpBinder。
               binder = sm->getService(String16("media.player"));
                if(binder != 0) {
               break;
            }
        //如果ServiceManager上还没有注册对应的服务，则需要等待，直到对应服务注册
//到ServiceManager中为止。
            usleep(500000);
        }while(true);
 
    /*
     通过interface_cast，将这个binder转化成BpMediaPlayerService，
     binder中的handle标识的一定是目的端MediaPlayerService。
   */
   sMediaPlayerService = interface_cast<IMediaPlayerService>(binder);
    }
    returnsMediaPlayerService;
}

```
有了`BpMediaPlayerService`，就能够使用任何`IMediaPlayerService`提供的业务逻辑函数了。例如`createMediaRecorder`和`createMetadataRetriever`等。
显而易见的是，调用的这些函数都将把请求数据打包发送给Binder驱动，由`BpBinder`中的`handle`值找到对应端的处理者来处理。这中间经历过如下的过程：
* （1）通讯层接收到请求。 
* （2）递交给业务层处理。

##子承父业
根据前面的分析可知，`MediaPlayerService`驻留在`MediaServer`进程中，这个进程有两个线程在`talkWithDriver`。假设其中有一个线程收到了请求，它最终会通过`executeCommand`调用来处理这个请求，实现代码如下所示：
**IPCThreadState.cpp**

```c
status_t IPCThreadState::executeCommand(int32_tcmd)
{
    BBinder*obj;
   RefBase::weakref_type* refs;
    status_tresult = NO_ERROR;
   
    switch(cmd) {
    case BR_ERROR:
       result = mIn.readInt32();
       break;
        ......
     caseBR_TRANSACTION:
        {
           binder_transaction_data tr;
           result = mIn.read(&tr, sizeof(tr));
           if (result != NO_ERROR) break;
           Parcel buffer;
           Parcel reply;
           if (tr.target.ptr) {
              /*
                 看到BBinder，想起图6-3了吗？ BnServiceXXX从BBinder派生，
                 这里的b实际就是实现BnServiceXXX的那个对象，这样就直接定位到了业务层的对象。
               */
               sp<BBinder> b((BBinder*)tr.cookie);
               const status_t error = b->transact(tr.code, buffer, &reply, 0);
               if (error < NO_ERROR) reply.setError(error);
             } else {
            /*
             the_context_object是IPCThreadState.cpp中定义的一个全局变量。可通过
             setTheContextObject函数设置。
             */
               const status_t error =
                             the_context_object->transact(tr.code,buffer, &reply, 0);
               if (error < NO_ERROR) reply.setError(error);
         }
       break;
    ......
    ```
`BBinder`和业务层有什么关系？还记得图6-3吗？我们以`MediaPlayerService`为例，来梳理一下其派生关系，如图6-5所示：

![](/media/15299381744168.jpg)

图6-5 `MediaPlayerService`家谱

`BnMediaPlayerService`实现了`onTransact`函数，它将根据消息码调用对应的业务逻辑函数，这些业务逻辑函数由`MediaPlayerService`来实现。这一路的历程，如下面的代码所示：
**Binder.cpp**

```c
status_t BBinder::transact(
    uint32_tcode, const Parcel& data, Parcel* reply, uint32_t flags)
{
   data.setDataPosition(0);
    status_terr = NO_ERROR;
    switch(code) {
        casePING_TRANSACTION:
           reply->writeInt32(pingBinder());
            break;
       default:
         //调用子类的onTransact，这是一个虚函数。
           err = onTransact(code, data, reply, flags);
           break;
    }
    if (reply!= NULL) {
       reply->setDataPosition(0);
    }
    returnerr;
}
```

**IMediaPlayerService.cpp**

```c
status_t BnMediaPlayerService::onTransact(uint32_tcode, const Parcel& data,
                                                  Parcel* reply, uint32_t flags)
{
   switch(code) {
        ......
        caseCREATE_MEDIA_RECORDER: {
           CHECK_INTERFACE(IMediaPlayerService, data, reply);
           //从请求数据中解析对应的参数
           pid_t pid = data.readInt32();
            //子类要实现createMediaRecorder函数。
           sp<IMediaRecorder> recorder = createMediaRecorder(pid);
           reply->writeStrongBinder(recorder->asBinder());
           return NO_ERROR;
        }break;
        caseCREATE_METADATA_RETRIEVER: {
           CHECK_INTERFACE(IMediaPlayerService, data, reply);
           pid_t pid = data.readInt32();
   //子类要实现createMetadataRetriever函数
           sp<IMediaMetadataRetriever> retriever =createMetadataRetriever(pid);
           reply->writeStrongBinder(retriever->asBinder());
           return NO_ERROR;
        }break;
      default:
           return BBinder::onTransact(code, data, reply, flags);
    }
}
```




