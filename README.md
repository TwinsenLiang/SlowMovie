# 慢电影墨水屏播放器（基于 Python）

![](Extras/img.jpg)

## 设备准备：

1. Raspberry Pi 4B(https://www.raspberrypi.org/products/raspberry-pi-4-model-b/)
2. 6inch HD e-Paper HAT from Waveshare(https://www.waveshare.net/wiki/6inch_HD_e-Paper_HAT)
3. VÄSTANHED from Ikea (https://www.ikea.cn/cn/zh/p/vaestanhed-wei-tan-he-hua-kuang-hei-se-20479217/)

## 说明：

最早是在网上看到慢电影这个项目觉得比较有意思。准备了手头的一些设备之后发现是个坑，微雪的 6 寸高清屏走的是 IT8951 的控制器。国外旧有 Python 项目并没有对高清屏 IT8951 的支持。于是就手动合并了两个 git 上面的项目，给有兴趣的小伙伴耍耍。

## 安装步骤：

```key
sudo raspi-config
```

或者参照其他方法[打开 SPI](https://www.raspberrypi-spy.co.uk/2014/08/enabling-the-spi-interface-on-the-raspberry-pi/)

首先下载仓库，然后安装IT8951的驱动和FFMPEG。

```key
git clone https://github.com/TwinsenLiang/SlowMovie.git
cd SlowMovie/IT8951
pip3 install -r requirements.txt
pip3 install ./
pip3 install ffmpeg-python
```
完成以后跑下测试，理应能看到只睡觉的企鹅。
```key
cd ～/SlowMovie/
python3 helloworld.py
```
![avatar](/images/sleeping_penguin.png)

下一步就直接运行命令看看电影是否拿得到。
```key
python3 slowmovie.py
```

## 设定自启动
### 方法一：修改树莓派启动项。
```key
sudo nano /etc/profile
```

在最后加入代码：
```key
cd ～/SlowMovie/
python3 slowmovie.py
```
### 方法二：安装PM2。
```key
sudo npm install -g pm2
```

设置PM2开机启动
```key
pm2 startup
```
运行此命令后会显示一个类似如下的命令，复制此命令到终端运行。

```key
[PM2] To setup the Startup Script, copy/paste the following command:
sudo env PATH=$PATH:/usr/bin /usr/local/lib/node_modules/pm2/bin/pm2 startup systemd -u pi --hp /home/pi
```

使用PM2启动slowmovie

```key
cd ~/SlowMovie/
pm2 start slowmovie.sh
```

使用PM2启动slowmovie

```key
pm2 save
```

可以运行下面语句关闭对应的脚本服务。注意，需要使用Pi用户，不能使用管理员用户。
```key
pm2 stop slowmovie
```

## 原始的一些仓库和资料：

Forked from [TomWhitwell/SlowMovie](https://github.com/TomWhitwell/SlowMovie)

Forked from [GregDMeyer/IT8951](https://github.com/GregDMeyer/IT8951)

Waveshare 针对 IT8951 的仓库 [Waveshare/IT8951-ePaper](https://github.com/waveshare/IT8951-ePaper)

慢电影原始项目(https://medium.com/@tomwhitwell/how-to-build-a-very-slow-movie-player-in-2020-c5745052e4e4)

Bryan 的帖子(https://medium.com/s/story/very-slow-movie-player-499f76c48b62)
