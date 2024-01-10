# Portable Container

一个轻量级的容器打包工具，用于部署的目标机器上没有安装docker时，将整个容器打包为一个单独的可执行文件。

---

**使用方式：**

```bash
./deploy-docker.sh EXE IMAGE APP [USER]
```

从docker镜像构建

```bash
./deploy-rootfs.sh EXE ROOTFS APP [USER]
```

从rootfs路径构建

```bash
./deploy-tar.sh EXE TAR APP [USER]
```

从tar文件构建

```bash
EXE: 生成的可执行文件名
APP: 容器内的入口程序
[USER]: 容器内程序执行时的用户（默认为root）
```

---

**运行方式：**

```bash
sudo ./app.run
```

使用 ``sudo``运行生成的可执行文件即可。默认将会进入容器内并运行指定的入口程序。

运行时**不需要**安装docker。

**不支持**命令行传参。

```bash
sudo ./app.run --help
```

可以运行help查看支持的选项

目前支持的选项：

* `-b, --bind`  将主机目录挂载到容器中
* `-d, --debug`  进入容器并运行bash
* `-e, --env`  设置容器的环境变量
* `-h, --help`  显示帮助信息
* `-o, --overlay`  指定overlay路径（如果不指定，则会使用tmpfs作为overlay）
* `-t, --tmpsz`  指定tmpfs作为overlay的大小（默认128M）
* `-v, --verbose`  打印脚本运行过程（通常用于调试脚本）

---

**自定义挂载：**

虽然可以通过命令行选项实现自定义挂载，但需要每次都手动输入挂载路径，对于一些固定的挂载项（如 `/mnt`目录下的外接硬盘等），会显得比较麻烦。

这时可以修改 `template.sh`文件（**TODO：**在 `deploy-xx.sh`中，通过命令行参数指定固定挂载）

例如希望将当前目录下的 ``config``挂载到容器内的 ``/config``，则加入这一行：

```bash
mount -o bind config $dir/rootfs/config
```

如果镜像内没有 ``/config``目录，则需要首先创建该目录：

```bash
mkdir $dir/rootfs/config
mount -o bind config $dir/rootfs/config
```

**自定义环境变量：**

与自定义挂载类似，对于一些固定的环境变量，每次都用命令行参数设置环境变量会比较麻烦

可以采用修改 `template.sh`文件的方法（**TODO：**在 `deploy-xx.sh`中，通过命令行参数指定固定环境变量）

例如希望添加环境变量 `ENV1=value1`，则在 `template.sh`最后几行找到 `/bin/env -i`，在此处添加环境变量：（注意有两处需要修改）

```bash
chroot $dirws/rootfs /bin/env -i ENV1=value1 ...
```

---

**限制：**

* 没有网络隔离，类似 ``--net=host``。
* 没有进程隔离，类似 ``--ipc=host``。
* 没有用户隔离，容器内程序默认以root身份运行，或以容器内特定用户身份运行。
* 不会自动加载容器内的环境变量（即Dockerfile里使用ENV定义的环境变量无效）。

---

**原理：**

将镜像内的文件系统制作成squashfs，并使用overlayfs在上面叠加一个tmpfs的可写层。

使用unshare实现挂载点隔离。

使用chroot实现文件系统隔离。

使用类似自解压程序的方式，将squashfs文件和运行脚本合并为一个可执行文件。
