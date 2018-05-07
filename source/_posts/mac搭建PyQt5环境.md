title: mac搭建Pyqt5环境
date: 2017/12/11 20:30:50
categories: python
comments: true
tags: [python,qt]
---
###  1.首先基于virtualenv 搭建一个python3的运行环境
virtualenv是一个十分好用的python工具，可以为不同的软件创建独立的“隔离”的Python运行环境。
#####  1. 首先，我们用pip安装virtualenv：

```
$ pip3 install virtualenv
```
##### 2.创建一个pyhton3的运行环境

```
jiangxqdeMBP:~ jiangxq$ virtualenv py3 --python=python3
```
可以通过**python=python3**来指定要安装的python版本，python3是mac的写法，其他linux系统需要制定为python2.7 或者python3.6
#### 3. 激活该运行环境
执行

```
jiangxqdeMBP:~ jiangxq$ source ~/py3/bin/activate
(py3) jiangxqdeMBP:~ jiangxq$
```
当用户名前出现该运行环境的名称时，表示环境已经激活了
### 2. 检查pip工具的版本 目前最新的为9.0.2 需要更新请 执行
```
pip3 install --upgrade pip
```
这里有个窍门是如果mac的默认python运行环境为python2.7，但是不想修改注册文件，可以直接打**pip3**，**pip3**是
是python3的pip工具，**pip**是python2的pip工具。
### 3. 使用pip工具安装PyQt5

```
pip3 install PyQt5
```
当PyQt5安装完成之后，其实Qt的组件此时已经可用了，如果要测试是否安装成功，可以新建一个Python项目，然后倒入PyQt5的包看看。
![image](https://note.youdao.com/yws/api/personal/file/WEBa771a15d091f47d6ebb57e09a1c5eff4?method=download&shareKey=c7c7e8069597b7ab8e8f58d4df01e4af)

### 4.在pycharm上安装QtDesign工具包
QtDesign是Pycharm上的可视化uI设计工具，可以拖动控件来达到实现设计界面的功能
安装Qtdesign 需要先安装QT
#### 1. 下载QT安装包
下载地址：http://iso.mirrors.ustc.edu.cn/qtproject/archive/qt/5.10/5.10.1/qt-opensource-mac-x64-5.10.1.dmg
下载完成后直接安装
#### 2.打开pycharm 点击preference 点击Tools 新建一个插件
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/WEBRESOURCE9bf5498a9bb100d2b67bf988c494f1be/1941)
 注意插件地址不要写错了，是qt5的安装路径
#### 3. 创建PyUIC 插件（将pydesigner的布局自动转化为python代码）




