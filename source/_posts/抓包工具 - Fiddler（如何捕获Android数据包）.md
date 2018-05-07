title: fiddler抓android数据包
date: 2016/08/03 20:20:17
categories: Android
comments: true
tags: [android,抓包]
---
## 抓包工具 - Fiddler（如何捕获Android数据包） ##

移动设备访问网络原理

先看看移动设备是怎么去访问网络，如图所示，可以看到，移动端的数据包是从wifi出去的。
![](http://i.imgur.com/88ZFpNh.png)
可以看得出，移动端的数据包，都是要走wifi出去，所以我们可以把自己的电脑开启热点，将手机连上电脑，Fiddler开启代理后，让这些数据通过Fiddler，Fiddler就可以抓到这些包，然后发给路由器（如图）：
![](http://i.imgur.com/xpx7qof.png)

二、Fiddler抓取android数据包所需条件

　　1、电脑需要安装Fiddler

　　2、测试手机需要支持Wifi

　　3、测试手机与电脑需要同一网络

　　4、所测APP需支持代理

　　注：Iphone、Ipad、WinPhone等支持代理手机均适用

1. 打开Wifi热点，让手机连上（我这里用的360wifi，其实随意一个都行）
![](http://i.imgur.com/lwCWyI7.png)
2. 打开Fidder，点击菜单栏中的 [Tools] –> [Fiddler Options] 
![](http://i.imgur.com/K87KQ8y.png)
Connections，设置代理端口：8888， 勾选 Allow remote computers to connect，即允许远程计算机连接Fiddler.
> 注：8888为默认端口号，可修改，但需注意两点，一是本机空闲端口，二是手机代理设置时要与fiddler的端口一致。
![](http://i.imgur.com/gwshRc7.png)

3、设置解密HTTPS的网络数据
　　Tools –>  Options-> Https，勾选"Decrypt HTTPS traffic"、"Ignore server certificate errors"，
![](http://i.imgur.com/uEHa5dw.png)

4、查看本机的无线网卡IP
　　设置了上面的步骤后，就可以在 Fiddler看到自己本机无线网卡的IP了（要是没有的话，重启Fiddler，或者可以在cmd中ipconfig找到自己的网卡IP，注：一定要开启本机的wifi热点），

![](http://i.imgur.com/JN06oW7.png)

也可以在CMD中查看本机网卡的IP，输入命令：ipconfig，
![](http://i.imgur.com/vkKMXHN.png)

5、手机连接本机的Wifi，并设置代理
　　每个品牌的手机设置wifi的方式可能不一样，这里以华为手机为例，如图8所示，将手机连接至PC的wifi

![](http://i.imgur.com/kkNUd7s.png)

勾选“显示高级选项”-> 代理 选择“手动” ->输入服务器主机名和服务器端口 ->IP选择“DHCP”->连接，即完成手机端设置代理操作，如图9所示

> 注：服务器主机名：Fiddler所在电脑IP（即开启wifi后，在fiddler或cmd中看到的无线网卡IP地址）
> 　　服务器端口： Fiddler使用的端口（即Options-Connections中设置的端口号）
![](http://i.imgur.com/LxaVORC.png)

6、手机下载安装Fiddler证书
　　连接上wifi后，手机打开浏览器输入代理IP+端口号（即是本机无线网卡IP，也是手机连接wifi时所设置的服务器主机名，这里的ip+端口号为192.168.191.1：8888），进入fiddler echo service页面，下载Fiddler的证书，如图10所示，点击FiddlerRoot certificate

![](http://i.imgur.com/7OhLqhq.png)

下载完成后，进行安装证书

![](http://i.imgur.com/DvxwP2J.png)

【注意】：如果打开浏览器碰到类似下面的报错，请打开Fiddler的证书解密模式（如上面的步骤3所示）：No root certificate was found. Have you enabled HTTPS traffic decryption in Fiddler yet?

设置完上面6个步骤后，即表明已设置完毕，此时用手机访问应用，就可以看到fiddler抓取到的数据包了.

![](http://i.imgur.com/iSn6kTI.png)