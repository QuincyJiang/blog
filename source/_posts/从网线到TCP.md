title: 从网线到TCP
date: 2020/03/12 19:00:50
categories: 计算机基础
comments: true
tags: [计算机基础]
---

# 一. 数据的传输形态 -数据信号和时钟信号同步
**波特率：**  每秒钟传送的码元符号的个数，是衡量数据传送速率的指标。

我们在以太网的电信号传输过程中，以一个**时钟周期**的**上升沿** 代表 1， 一个**时钟周期**的**下降沿** 代表0.

**为什么要用上升沿 下降沿 而不是一个高电平状态和低电平状态代表0 和 1？**

因为哪怕我们在不同主机之间，通过连接额外的时钟同步线缆来进行时钟同步，尤其是带宽比较高（带宽高 意味着在一秒内传输的数据更多，代表时钟周期更短，可能每个时钟周期只有纳秒级的间隔，如果只使用高低电平来进行编码，会导致容错率低。一点点点的时钟偏移都不行，都会导致误差。）

> 时钟偏移：
![](/media/15841064246957.jpg)
上面代表数据 下面代表时钟周期， 在每个时钟周期到来时，读取当前时钟周期上方数据信号所代表的数据。如果时钟周期到来，上方为低电平，代表0，上方为高电平 代表1。
如果两端计算机的时钟同步信号 相较于数据信号 发生了偏移，会导致解析出的数据流发生错误。

# 二. 决定数据读取准确性 -曼彻斯特编码
为了提高数据传输时 **时钟信号的容错率**， 采用一种 电信号电平变化的**过程** 来表述 0 和 1 这两种状态。这就是所谓的 **曼彻斯特编码**。

![](/media/15841069325724.jpg)

一个低电平 往 高电平 转换的过程 成为**上升沿** 代表数据 1 
一个高电平 往 低电平 转换的过程 称为 **下降沿** 代表数据 0

![](/media/15841070686296.jpg)

如上图所示 可以读取出 数据为 0 1 0 0 1 0 1 1...

**为什么3位和4位中间的上升沿 没有被计算机认为是数据1呢？**

因为数据传输有个固定的带宽。比如**10mbps**，有了带宽可以轻易计算出 时钟周期间隔为 **1 / (10 * 1024 * 1024 * 8)** 秒。
有了这个数据 我们会发现 3 和 4 位之间那个电信号 是在时钟周期间隔内的 计算机就会过滤掉这个数据。

**曼彻斯特编码 完美解决了 当时钟频率 不是 完美匹配的时候的数据读取。**

# 三. 0 和 1 如何变成有意义的信息？ - 帧协议

当把网线挑开 接入 示波器时 我们可以看到 电信号的变化如图所示

![](/media/15841075204413.jpg)


0 和 1 本身没有任何意义 如果要让传输数据有意义 就必须决定 多少个0 1 代表一个完整数据 和 0 1 的起始点在哪里？ 

一组0 和 1， 我们称为 **数据帧**。

在网络传输中 构造帧的 一般有两种协议。

### 1. HDLC帧： 高级数据链路控制帧

  它定义了一组特殊信号 代表帧的起点位： **01111110** 
  只要收到这么一组信号 就代表是帧的起点。
   ![](/media/15841082789542.jpg)


比如这样 找到0111110 之后 后面就是 按 每 8 位 代表一个字节 表示一个特定字符了。
 
注意 
![](/media/15841084043997.jpg)

这里在数据中 同样出现了 **0111110** 为了保证对端解码不会出错 当发送数据时出现了**6个1 并列在一起的时候**， 发送端会规避这种情况 **将中间插入一个 0** ，接收端同样会根据算法纠正这个额外的0。
插入的这个0， 称之为 **位填充**。 

### 2. 以太网帧 

以太网数据传输时  按照

* 静默期 （啥都不干 等 96bit数据的传输时间） 
* Preamble期 （56个 0 1 交替 给你准备时间去校准自己的同步 ）
* 定界符  **101010 11** （最后用2个1结尾 ）
![](/media/15841087774003.jpg)

上图 从左往右
* 收到定界符后，后面全部是数据段了。
![](/media/15841089528054.jpg)

确定了如何确定帧的起始位置，
**那么 帧长度 应该是多少呢？**

在速率和准确性做了权衡之后，计算得出 一个帧在 64 - 1500 个字节 会比较合理。在高性能网络上 一个帧可以传输甚至超过 9000个字节。
 
# 四、帧中到底包含了什么信息？-帧结构

其实网络世界的链接类型，一般是下面这两种方式的组合

### 1. 直接相连 
![](/media/15841093897776.jpg)
这种点对点的网络，比较简单 一般使用**PPP格式**的数据帧，主要用在主干网中 进行点对点传输。后面会说到。 

### 2. 局域网内 多对多链接

以太网协议 **也被称为： 多点数据链路协议**

所谓以太网，其实就是指的**局域网**，是最常见的 **一台交换机 链接多台上网设备的 结构**。
![](/media/15841095940398.jpg)


先看看以太网的帧结构

![](/media/15841096858785.jpg)


从左往右看。

* 最左边是**Premable**部分，已经说过了，是给你做同步 并且告诉你数据从何处开始。

接下来后面都是数据部分了。

* **DestinationAddress**: 我想跟谁交流？（目标网卡地址）**6个字节** 如果我想把数据发给局域网的所有计算机 可以填一个特殊值在这里 （ff:ff:ff:ff:ff:ff）
* **SourceAddress**:  源地址 （我自己的网卡地址 ）**6个字节**
* **EthernetType**: 网络类型 **2个字节** 告诉接收方 后面的Payload你要怎么去解析 比如如果这里写 **0800** 就代表后面的Payload是IP数据包
* **Payload**: 数据段 根据前面的网络类型标识去解析。 （46 - 1500字节之间）
* **FrameCheck sequence**：帧校验序列。 每当发送者发送这么一段数据时，要把 **从 DestinationAddress 到 Payload 结束** 这中间 总共的字节数 填在这个地方。 接受者通过这个字段判断自己接收的数据是否是完整的。


再看看上面提到过的PPP帧
![](/media/15841107840499.jpg)

长这样。

还记得前面的**HDLC**协议吗？ 这里 前后的两个 **Flag** 就是那个 **0111110**
中间是数据段，为了数据段也出现0111110，发送方会在中间插入 0 做 位填充， 上面已经提到过了。

* **Address**： 地址位 1位 没啥卵用 PPP帧是点对点传输 目标地址就是网线另一头的那个计算机 这里留下一个Address 估计是为了以后扩展？目前一直没用 写死的FF
* **Control**: 跟上面一样 没卵用 一直写死的 03 大小为 1位、
* **Protocol**： 等于以太网帧里面的 EthernetType 表示怎么解析后面的Payload
* **Payload**： 等同以太网帧里的 Payload 存的数据 需要按上面的协议解析 一般是 40 - 1500 字节
*  **FCS**: 4字节 帧检查序列

我们的网络世界 
其实就是 家里的电脑 手机 在小小局域网里 通过 路由器 经过主干网 跟世界各地的其他 小小局域网 链接了起来。 

![](/media/15841126002487.jpg)

至此 我们只聊到了 **经典的OSI 7层模型的最下面两层**。

# 五、 OSI模型
经典的网络层级模型，被分成了如下7层。
我先把它贴在这里，后面会经常回顾到这个定义：
> 
* **应用层**
网络服务与最终用户的一个接口。
协议有：HTTP FTP TFTP SMTP SNMP DNS TELNET HTTPS POP3 DHCP
* **表示层**
数据的表示、安全、压缩。（在五层模型里面已经合并到了应用层）
格式有，JPEG、ASCll、DECOIC、加密格式等
* **会话层**
建立、管理、终止会话。（在五层模型里面已经合并到了应用层）
对应主机进程，指本地主机与远程主机正在进行的会话
* **传输层**
定义传输数据的协议端口号，以及流控和差错校验。
协议有：TCP UDP，数据包一旦离开网卡即进入网络传输层
* **网络层**
进行逻辑地址寻址，实现不同网络之间的路径选择。
协议有：ICMP IGMP IP（IPV4 IPV6）
* **数据链路层**
建立逻辑连接、进行硬件地址寻址、差错校验等功能。（由底层网络定义协议）
前面说的 **以太网帧 HDLC帧** **以太网传输控制协议** **PPP帧的传输控制协议** 都属于这一层。
* **物理层**
建立、维护、断开物理连接。**上面说到的 曼彻斯特编码 包括网线分股 等等 属于物理层。** 可以认为 物理层 就是把 物理信号 转换为了 数据信号。

# 六、 我在广州家中小小局域网里的手机里 怎么发QQ消息给 北京小明家里局域网下的手机？ - IP协议

互联网的世界：
![](/media/15841128013455.jpg)

为了更详细的分析这个问题 另外画了个图

![](/media/15841128914724.jpg)

**为了将数据 从A 发送给 另一个城市的 B**
要怎么办呢？

先考虑下 如果主机A  在 发送出去的 **以太网数据帧中** 将**DestinationAddress** 填写成 **B的网卡地址**可以吗？ 
答案肯定是不行的，因为A所在的局域网里会发现 根本找不到跟B 的mac地址相同的设备。 如果我想把以太网数据 发送给 旧金山（SFO）的路由器，在主干网络中进行远程传输，因为主干网使用的是PPP帧，里面是没有地址信息的，那么主干网中的路由器，要如何知道，我这个数据要往哪一条链路传递呢？
这势必要求我们提出一种更通用的地址格式，在互联网中传播。

由此 诞生出了  **IP地址** 协议

我们再来看一下 使用 IP 协议时  数据是怎么从A 传输到 B的

1. A 会将 含有B的IP地址的数据包 发送到A所在局域网的路由器 SFO 
2. 在SFO的路由器中构造并维护了一个路由表，通过路与表，SFO路由器决定要经由3号线路 转发给丹佛（DEN）的核心路由器（主干网中的路由器被称之为核心路由器），这个查表 决定走3号线路的过程 称之为 转发。 构造路由表的过程 称之为路由。于是 路由器将以太网帧转换为PPP数据包 发送给了DEN的路由
3. 同样 DEN 将数据转发给NYC，由NYC 再将数据发送到以太网中的主机B。

那么路由表长啥样呢？

![](/media/15841139640814.jpg)

一般是这样

前面表示**匹配哪个地址段** 斜杠后面跟的是匹配**目标IP地址的2进制的前多少位**。

这个路由表 按照位数长度，**优先按照更精确的规则去匹配**。

比如目标地址是 `172.17.6.2 `
就会匹配到 `172.17.6 / 24` 走 3号线路
而不是`172.17 / 16` 走2号线路。

# 七、 喂！局域网里的你们，谁可以接收我的数据包啊？回个话吧  -ARP协议

我们再来回顾下完整的 A 到 B 的数据传输过程，看看数据是怎么填入以太网帧 并转为PPP帧后 经由主干网传输到目标端的以太网中的路由NYC，然后由NYC传送到目标主机B的过程。

![](/media/15841143487865.jpg)

1. A自己的主机地址是 192.168.9.2 
2. A的路由器地址是 192.168.9.1
3. A的子网掩码是255.255.255.0
4. A要发送数据给192.168.20.2
5. 首先用192.168.20.2跟自己的ip 192.168.9.2用子网掩码 255.255.255.0的二进制位（1111111111110000）做个与运算。
6. 发现与完之后的结果 192.168.9和 172.17.2不一样，那么说明 目标端主机跟我不在同一个局域网内。我要把数据先发给SFO路由器。
7. A要在以太网内把数据发给路由器，一定要先知道路由器的mac地址。
8. A使用了一种称之为 **ARP广播**的协议，其实就是在局域网内大喇嘛喊一声”谁的IP是192.168.9.1， 回复一下你的mac地址吧“
ARP因为是在以太网中传输，所以ARP也是标准的以太网帧。
![ARP帧](/media/15841152201194.jpg)
大喇叭会吧目标地址填写成**”FF:FF:FF:FF“**，源地址填写成自己的MAC地址，以太网类型填写成**”2c2d“**表示是ARP类型，然后再Payload中塞下一坨数据。
**Payload的数据格式比较简单，就是把IP和MAC地址做了映射，从前往后表示
 【硬件地址类型（MAC地址）】
 【协议地址类型（IP地址）】
 【硬件地址长度】
 【协议地址长度】
 【OpCode操作码（如果是我在问，就写0， 如果是路由器回复，就写1）】
 【我的MAC地址】
 【我的IP地址】
 【你的MAC地址是多少？写在HardWareAddressOfTarget这里】
 【我要问的那个主机的IP,只有IP是这个的相应，其他主机不要响应我】**

9. 局域网所有设备均可听到该广播，只有路由器发现自己地址匹配，便把自己的MAC地址填在了ARP数据包的**HardWareAddressOfTarget**里，把**OpCode**写成1再广播出去。
10. A收到了路由器的ARP数据帧，解析出了MAC地址。将要发给远端主机的数据 封装在**PayLoad**中，同时在以太网帧里，把我的地址（自己的MAC),目标主机地址（SFO路由器的MAC地址），以太网类型（IP数据包），**Payload**（IP数据包）设置好，发送给了路由器SFO。
11. SFO获取到这个以太网帧，根据以太网类型字段，解析出了IP数据包，拿出IP地址跟自己的本地路由表相匹配，将数据包封装成**PPP**帧（设置协议为IP协议，将IP数据包 放在Payload中，前后加上011110这个Flag，数据段的最后面加上一个帧校验序列就OJBK了），选择合适的链路发送到其他主干网的核心路由器。
12. PPP数据包在核心路由器间传递，直到传递给了NYC的路由器。
13. NYC的路由器收到了PPP帧后，解析PPP帧的**Protocal**字段，发现是IP数据包，便将IP数据包解析出来，拿到了IP地址。
14. NYC路由器会发送一个ARP请求在自己的局域网中。
15. 目标主机相应，并回复了自己的MAC地址
16. NYC路由器会将IP数据包封装成以太网数据包，同时设置好目标端MAC地址，将数据发送到目标主机B。


至此， 漫长的数据传输过程 终于结束了。


# 八、IP数据包里都有啥
一图流：

![](/media/15841170740799.jpg)

直接看图吧。

Payload里塞进去的就是IP数据包。
EthernetType写的是0800表示是IP数据包。

# TCP传输控制协议

前面我们说了， 数据想要在以太网中进行传输，必须以帧的方式进行，要么是一个以太网帧，要么是一个PPP帧。
但是一个帧中的Payload字段，一般最大不会超过1500个字节。如果为了传输更多的数据，超过了1500个字节呢？ 那就要对数据进行分包。

要对数据进行分包，首先要解决的一个问题就是 如何处理可能出现的丢包？

比如链路故障，比如路由器正在更新路由表，等等都有可能会导致一个数据包丢失。我们希望可以重新发送丢失的数据包。

第二个问题，对数据做了分包之后，不同的包到达的先后时间不一致，我们还要考虑如何在接收端将包重新按照正确的次序排列起来，也就是数据重排问题。

第三个问题， A 在将数据发送给B的时候，可能有些是要发送给浏览器程序的，有些是要发送给微信程序的，B收到数据后，如何知道将哪些数据，交给哪些程序处理呢？ 这涉及到多会话问题。

第四个问题， 当A主机用最快的速度网旧金山的路由器发送数据，同时，旧金山的路由器还承载了很多其他接入网的设备的数据，从旧金山到丹佛的这条数据链路非常繁忙，导致旧金山路由器可能会丢失一部分数据包，我们希望当遇到对端设备处理不来数据时，发送方可以知道，同时降低自己的发送速率。这些涉及到流量控制问题。

TCP协议，就是为了解决上述四个问题的。

* TCP协议是面向连接的。所谓面向连接是说，任何主机想要给对端主机发送数据之前，必须先建立一个TCP链接。
* TCP是字节流服务。所谓字节流服务是说，任何主机之间，只要建立了TCP链接，后续只需要吧一段一段的字节流放入以太网的Payload包中即可。TCP协议可以把很长的数据 分割成一段一段更小的字节流。每一段都可以放入单独的IP报文中。在TCP协议中，主机B收到了任何的段都会返回一个ACK表示我收到了你的段。如果主机A在一定时间没有收到B的ACK， 主机A会重新发送这个包。
* TCP是可靠的。上面说的确认和重传是TCP保证可靠性的方法之一。TCP同样会对每个数据段进行编号，在接收端收到数据段后，会将数据段按照编号重新排列，同时会删除重复的段。

TCP包结构

![](/media/15841186975949.jpg)

它是被包在以太网数据帧中的Payload中，
排列在IP头后面。

在IP头中，
**SourceAddress**表示发送端主机的IP地址
**Destination Address** 表示目标端主机的IP地址
路由器会根据这两个字段，来判断如何转发和路由。
**Protocol** 表示协议类型 其中 6 表示是TCP协议。

当对端主机解析到协议类型 = 6 时，就知道是TCP数据包了。

再看TCP头结构

![](/media/15841189243240.jpg)

**SourcePort** 表示发送端主机端口号

**Destination Port** 表示目标主机端口号

端口是用来区分是给哪个应用程序读取的。也就是用来区分TCP链接的。

**因为一组IP 和 端口号 决定了一个唯一的TCP链接。**

**CheckSum** 检查字段， 用来检查TCP数据块的数据完整性。是相较于以太网的帧校验序列之外的一个额外的检查。
**Sequence Number** 序列号： 每次链接开始时，被初始化为一个随机数，每次发出一个序列，该序列号增加1.接受者收到后会根据该序列号将数据包进行重拍。
**Acknowledgment Number** 确认号：对接收段，对接受到的SquenceNumber + 1 返回给发送端。表示我已正常收到该段，我想接收下一个段，下一个段的序列号是ACK。 

**URG/ACK/RST/SYN/FIN/** 标记位：表示当前处于连接的什么状态。

通过经典的三次握手

![](/media/15841199365700.jpg)


客户端和server端 彼此会进入 ESTIABLISHED状态，表示连接已建立。


三次握手 握的是TCP数据段的其实序列号。这个一定要知道。
每次ACK表示 我收到了你发来的第k个TCP段。你可以发K+1过来啦。

