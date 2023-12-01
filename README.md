# Portable Container

一个轻量级的容器打包工具，用于部署的目标机器上没有安装docker时。

---

**使用方式：**

```bash
./deploy.sh <docker image>
```

将编译好的docker镜像名提供给deploy.sh脚本，将自动生成一个叫 ``app.run``的可执行文件。

**运行方式：**

```bash
chmod +x ./app.run
sudo ./app.run
```

给 ``app.run``提供可执行权限后，使用 ``sudo``运行即可。默认将会进入容器内并运行 ``/bin/bash``。运行时不需要安装docker。

支持命令行传参。

---

**自定义挂载：**

容器内程序默认无法访问外部路径，如有需要，则修改template.sh，在其中加入希望挂载的目录。

例如希望将当前目录下的 ``config``挂载到容器内的 ``/config``，则加入这一行：

```bash
mount -o bind config $dir/rootfs/config
```

如果镜像内没有 ``/config``目录，则需要首先创建该目录：

```bash
mkdir $dir/rootfs/config
mount -o bind config $dir/rootfs/config
```

**自定义入口程序：**

运行 ``app.run``后默认启动 ``/bin/bash``，如果需要启动自定义程序，则需修改template.sh中的倒数第三行，将 ``/bin/bash``替换为自己的程序路径。

例如希望运行 ``/app/app.sh``，则修改为：

```bash
chroot $dir/rootfs /app/app.sh $@
```

---

**限制：**

* 没有网络隔离，类似 ``--net=host``。
* 没有进程隔离，类似 ``--ipc=host``。
* 没有用户隔离，容器内程序全部以root身份运行。
* 容器内的文件修改不会被保存，每次运行都会重置。除了通过自定义挂载的目录。
* 不会自动加载容器内的环境变量（即Dockerfile里使用ENV定义的环境变量无效）。

---

**原理：**

将镜像内的文件系统制作成squashfs，并使用overlayfs在上面叠加一个tmpfs的可写层。

使用unshare实现挂载点隔离。

使用chroot实现文件系统隔离。

使用类似自解压程序的方式，将squashfs文件和运行脚本合并为一个可执行文件。
