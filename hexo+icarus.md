# 安装hexo
### 1. 安装node
### 2. 生成ssh公钥秘钥对 并且添加到github上
### 3. 安装hexo
```
npm install -g hexo
```
 
### 4. 初始化hexo
```
hexo init hexo
```
 
### 5. 安装部署依赖文件
进入hexo目录  
```
npm install
```
 
### 6. 安装hexo-server

```
npm install hexo-server
```

hexo-server 会创建本地服务器，你可以使用hexo s
来在本地预览你的博客效果。
### 6. 生成hexo的目录结构

```
hexo generate
```
### 7. 配置_config.yml文件
需要修改博客根目录的config文件，添加上你的github.io仓库地址，注意，你的ssh公钥此时应该已经添加到github上了 我的配置如下

```
deploy:
  type: git
  repository: https://github.com/QuincyJiang/QuincyJiang.github.io.git
  branch: master
```

### 8.目录结构以及写作流程

```
/scaffolds
source
/themes
.gitignore
_config.yml
package.json
package-lock.json
```

* public文件夹是每次hexo g 自动生成的网页静态代码 
* source中存放日志的原始md文件，每次写了新的文章，就需要将文章放置在该目录下，然后
```
hexo g
```
来生成静态网页代码，生成的代码会创建
```
/public
```
文件夹，
 如果启用了 about tags categories等界面 也需要在source目录中创建对应的文件夹（about，tags，categories文件夹，内部放index.md文件，文件头以

```
title: "About"
layout: "about"
---
```
这种格式编写。
* 当文章写完并且已使用
```
hexo g
```
 生成public文件夹后，使用
```
hexo s
INFO  Start processing
INFO  Hexo is running at http://localhost:4000/. Press Ctrl+C to stop.
```
 在浏览器输入
```
localhost:4000
```
来本地预览博客效果。
* 确认无误，使用

```
hexo d
```
部署博客到github.io仓库。

# 主题配置
### 下载主题
克隆你喜欢的主题到/themes文件夹内。我使用的是**icarus**主题
### 自定义主题配置
1. 修改根目录config文件，指定主题为icarus

```
theme: icarus
```
2. 进入themes/icarus/目录下,修改config文件

``` json
# Menus
menu: # 配置主页上方的分类项 如果需要开启 要在博客根目录的source 文件夹下创建对应的同名文件并防止index.md 上面已经说过了
  Home: . 
  Archives: archives
  Categories: categories
  Tags: tags
  About: about

# Customize
customize:
    logo: # 左上方小logo 将png文件放在主题目录下的css/image目录下
        enabled: true
        width: 40
        height: 40
        url: images/logo.png
    profile:
        enabled: true # Whether to show profile bar
        fixed: true
        avatar: css/images/avatar.png
        gravatar: # Gravatar email address, if you enable Gravatar, your avatar config will be overriden
        author: QuincyJiang
        author_title: Coder & FilmPlayer
        location: Guangzhou, China
        follow: https://github.com/QuincyJiang
    highlight: androidstudio # 代码高亮风格，需要md文件格式支持，在代码块外 要显示标注代码语言 比如
    ···java
    public static void main(){
        ...
    }
    ...
    sidebar: right # sidebar position, options: left, right or leave it empty
    thumbnail: true # enable posts thumbnail, options: true, false
    favicon: css/images/avatar.png
    social_links:
        github: https://github.com/QuincyJiang
        weibo: https://weibo.com/2425393311/
        photo: http://aquencyua11.lofter.com/
    social_link_tooltip: true # enable the social link tooltip, options: true, false

# Widgets
widgets:
    - recent_posts
    - category
    - archive
    - tag
    - tagcloud
    - links

# Search 是否启用insight搜索
search:
    insight: true # you need to install `hexo-generator-json-content` before using Insight Search
    swiftype: # enter swiftype install key here
    baidu: false # you need to disable other search engines to use Baidu search, options: true, false

# Comment 是否开启评论功能 需要disqus账号
comment: # 
    disqus: https-quincyjiang-github-io
    duoshuo: # enter duoshuo shortname here
    youyan: # enter youyan uid here
    facebook: # enter true to enable
    isso: # enter the domain name of your own comment isso server eg. comments.example.com
    changyan: # please fill in `appid` and `conf` to enable
        appid:
        conf:
    gitment:
        owner: #QuincyJiang
        repo: #https://github.com/QuincyJiang/comments.git
        #Register an OAuth application, and you will get a client ID and a client secret.
        client_id: 
        client_secret: 
    livere: # enter livere uid here
    valine: # Valine Comment System https://github.com/xCss/Valine
        on:  # enter true to enable
        appId:  # enter the leancloud application appId here
        appKey: # enter the leancloud application appKey here
        notify: # enter true to enable <Mail notifier> https://github.com/xCss/Valine/wiki/Valine-%E8%AF%84%E8%AE%BA%E7%B3%BB%E7%BB%9F%E4%B8%AD%E7%9A%84%E9%82%AE%E4%BB%B6%E6%8F%90%E9%86%92%E8%AE%BE%E7%BD%AE
        verify: # enter true to enable <Validation code>
        placeholder: Just Do It # enter the comment box placeholder
    

# Share
share: default # options: jiathis, bdshare, addtoany, default

# Plugins
plugins:
    lightgallery: true # options: true, false
    justifiedgallery: true # options: true, false
    google_analytics: # enter the tracking ID for your Google Analytics
    google_site_verification: # enter Google site verification code
    baidu_analytics: # enter Baidu Analytics hash key
    mathjax: false # options: true, false

# Miscellaneous
miscellaneous:
    open_graph: # see http://ogp.me
        fb_app_id:
        fb_admins:
        twitter_id:
        google_plus:
    links:
        github: https://github.com/QuincyJiang

```
# 托管hexo博客源码
为了保证切换电脑也可以保留原博客的风格，我们需要将博客的配置用git托管起来
### 1.创建hexo源码仓库
去gitub 新建一个 源码仓库 

```
https://github.com/QuincyJiang/blog.git
```
### 2. 将博客代码使用git托管
博客根目录在我们创建hexo项目的时候，就已经生成了一个gitignore文件

```
.DS_Store
Thumbs.db
db.json
*.log
node_modules/
public/
.deploy*/
```
因为mode_modules public .deploy 文件夹都是会动态生成的，所以被添加到git忽略文件列表中了。注意，theme目录下我们克隆下来的第三方theme，它的远程仓库还是跟克隆时的目标仓库保持一致的，我们需要解除它远程仓库的关联，这样推送代码的时候才不会吧主题推送到其他地方。
#### a 清除第三方主题的远程仓库

```
cd themes/icarus/
rm -rf .git
```
#### b 修改主题目录下的gitignore文件
因为主题的config配置文件我们也要托管起来，对博客的自定义配置主要都是在这里修改的。
修改很简单 删除忽略文件中的config.yml就好了

#### c 创建版本库并与远程仓库链接

```
cd ../../
git init
git add . 
git remote add origin https://github/com/QuincyJiang/blog.git
git commit -m "init commit"
git push -u origin master
```

# 切换电脑后重新恢复博客环境

### 克隆博客源码
 
```
git clone https://github/com/QuincyJiang/blog.git
```
### 配置基础环境

```
安装node
安装git
配置公钥到github
```

### 安装hexo

```
npm install -g hexo
npm install hexo --save
npm install hexo-server
npm install
```
至此hexo安装完成，回到熟悉的source/_post 目录愉快开始写作吧