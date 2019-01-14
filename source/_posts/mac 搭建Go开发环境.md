title:mac 搭建Go开发环境
date: 2019/01/14 13:18:50
categories: 后端技术
comments: true
tags: [后端技术,go]
---


本文基于macos 10.13.6 ，采用vim+go插件的方式，包括了配置vim语法高亮，自动补全等设置。
#  一、安装Golang
 
### 1.[官网地址](https://golang.org/dl/)下载pkg文件 双击安装
默认安装位置在

```shell
/usr/local/go/bin
```

### 2.配置环境变量

```shell
export PATH=$PATH:/usr/local/go/bin
```

### 3.终端输入


``` shell
go version
go version go1.11.4 darwin/amd64
```

即表示安装成功

# 二、配置vim

### 1.安装vim （已安装的可跳过）

```shell
brew install vim
```
mac 默认安装位置在

```shell
/usr/local/bin/vim
```
可以通过

```shell
which vim
```
来查看vim安装路径。

### 2.安装vim插件管理工具Vundle

```shell
mkdir ~/.vim/bundle
$ git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
```
### 3.修改vim配置文件
Vim 的全局配置对所有用户生效。路径一般在

```shell
/etc/vim/vimrc
```
或者

```shell
/etc/vimrc
```
用户个人的配置在

```shell
~/.vimrc
```
我们修改个人配置即可。如果用户目录不存在，直接

```shell
touch .vimrc
```
新建一个文件，如果存在，使用vim打开

#### a. 安装vim插件管理工具Vundle

```shell
$ mkdir ~/.vim/bundle
$ git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
$ vim ~/.vimrc
```
文件顶部添加：

```shell
set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
```
#### b. 设置语法高亮及显示行号
文件中增加：

```shell
syntax on
set nu!
```
####c. 安装vim-go
在`vundle#begin`和`vundle#end`间增加如下插件配置

```shell
Plugin 'fatih/vim-go'
```
esc进入命令模式，输入 `:PluginInstall`,成功后提示Done!

此时vim如下特性被支持：


- 语法高亮
- 保存时自动format,import

#### d. 安装go.tools Binaries
vim中执行命令`:GoInstallBinaries`,成功后提示Done!.

此时vim如下特性被支持：

- 新起一行输入fmt.，然后ctrl+x, ctrl+o，Vim 会弹出补齐提示下拉框，不过并非实时跟随的那种补齐，这个补齐是由gocode提供的。
- 输入一行代码：time.Sleep(time.Second)，执行:GoImports，Vim会自动导入time包。
- 将光标移到Sleep函数上，执行:GoDef或命令模式下敲入gd，Vim会打开$GOROOT/src/time/sleep.go中 的Sleep函数的定义。执行:b 1返回到hellogolang.go。
- 执行:GoLint，运行golint在当前Go源文件上。
- 执行:GoDoc，打开当前光标对应符号的Go文档。
- 执行:GoVet，在当前目录下运行go vet在当前Go源文件上。
- 执行:GoRun，编译运行当前main package。
- 执行:GoBuild，编译当前包，这取决于你的源文件，GoBuild不产生结果文件。
- 执行:GoInstall，安装当前包。
- 执行:GoTest，测试你当前路径下地_test.go文件。
- 执行:GoCoverage，创建一个测试覆盖结果文件，并打开浏览器展示当前包的情况。
- 执行:GoErrCheck，检查当前包种可能的未捕获的errors。
- 执行:GoFiles，显示当前包对应的源文件列表。
- 执行:GoDeps，显示当前包的依赖包列表。
- 执行:GoImplements，显示当前类型实现的interface列表。
-安装UltiSnips 执行:GoRename [to]，将当前光标下的符号替换为[to]。


#### e.安装YCM(Your Complete Me)
在`vundle#begin`和`vundle#end`间增加如下插件配置：

```shell
Plugin 'Valloric/YouCompleteMe'
```

在vim内执行`:PluginInstall`命令，成功后提示Done!.
> 注： 此步在mac上可能会出现异常，查看4异常处理.
 
 安装完毕后如下特性被支持：
 
 - 逐字的实时补全功能


#### f.安装UltiSnips

在`vundle#begin`和`vundle#end`间增加如下插件配置：


```shell
Plugin 'SirVer/ultisnips'
```
在vim内执行`:PluginInstall`命令，成功后提示Done!.

#### g. 解决YCM与UltiSnips的快捷键冲突：

文件中增加如下配置：


```shell
" YCM settings
let g:ycm_key_list_select_completion = ['', '']
let g:ycm_key_list_previous_completion = ['']
let g:ycm_key_invoke_completion = ''
" UltiSnips setting
let g:UltiSnipsExpandTrigger="<Tab>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"
```

#### h. 安装molokai theme

```shell
$ mkdir ~/.vim/colors
$ cd ~/.vim/colors
$ wget https://github.com/fatih/molokai/blob/master/colors/molokai.vim
```
打开vimrc文件，增加如下配置

```shell
colorscheme molokai
```
#### i. 自动格式化导包

文件中增加如下配置：

```shell
" vim-go settings
let g:go_fmt_command = "goimports"
```
#### j.最终vimrc内容

```shell
set nocompatible              " be iMproved, required
filetype off                  " required

colorscheme molokai

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()


" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'
Plugin 'fatih/vim-go'
Plugin 'Valloric/YouCompleteMe'
Plugin 'SirVer/ultisnips'


" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required

syntax on
set nu!

" vim-go settings
let g:go_fmt_command = "goimports"
" YCM settings
let g:ycm_key_list_select_completion = ['', '']
let g:ycm_key_list_previous_completion = ['', '']
let g:ycm_key_invoke_completion = ''

" UltiSnips setting
let g:UltiSnipsExpandTrigger="<Tab>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"

```
### 4.异常处理

在第三部安装YouCompleteMe插件的时候，mac系统可能会爆如下错误

```shell
The ycmd server SHUT DOWN (restart with :YcmRestartServer)
```
参考[github上这个issue](https://github.com/Valloric/YouCompleteMe/issues/914)
解决办法如下

```shell
brew install cmake
cd ~/.vim/bundle/youcompleteme
install.py --clang-completer --js-completer
```

