# 特征

- 使用 Docker 编译内核，无需在宿主机中配置编译环境
- 使用 Busybox 制作初始内存磁盘
- 使用 QEMU 模拟器加载内核
- 对于网络问题，均已给出国内替代方案

# 测试环境

```
$ uname -a
Linux 5.15.0-60-generic #66-Ubuntu SMP Fri Jan 20 14:29:49 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux

$ cat /etc/issue
Ubuntu 22.04.2 LTS \n \l

$ lscpu
Model name:            Intel(R) Core(TM) i5-8260U CPU @ 1.60GHz

$ cat /proc/meminfo
MemTotal:       16122780 kB

$ docker --version
Docker version 23.0.1, build a5ee5b1

$ qemu-system-i386 --version
QEMU emulator version 6.2.0 (Debian 1:6.2+dfsg-2ubuntu6.6)
```

> **注意：由于多核编译中发现 4G 内存会出现 out of memory 现象，建议内存配备 8G 或以上。**

# 演示视频

[5分钟编译Linux-2.6.26内核+使用busybox制作initrd+qemu运行](https://www.bilibili.com/video/BV1vY41167EG)

# 步骤

## 克隆仓库

```
git clone https://gitee.com/jklincn/build-linux-2.6.26.git
cd build-linux-2.6.26
```

> **注意： Github 仓库为 Gitee 镜像仓库，可自行更改 URL**
>
> Github 仓库地址：https://github.com/jklincn/Build-linux-2.6.26 ，欢迎前往 star

仓库中包含

- `dockerfile`：构建 docker 镜像的文本文件
- `patch-2.6.26`：linux-2.6.26 内核的补丁文件

## 准备Docker镜像

### 安装 Docker Engine

参见 [Install Docker Engine](https://docs.docker.com/engine/install/)

### 构建镜像

```
docker build -t build-env .
```

构建速度取决于处理器性能与网络质量（已使用 opentuna 源加速）

### 镜像使用方法

```
docker run --rm -v $(pwd)/[source]:/src build-env [target]
```

- `[source]`：源代码文件夹
- `[target]`：对应 Makefile 中可选目标，当 target 为空时，默认 make help

例如，编译 linux 内核时，可以使用如下命令生成默认配置文件

```
docker run --rm -v $(pwd)/linux-2.6.26:/src build-env defconfig
```

> **注意：镜像的 make 命令自动使用 -j 参数开启全核编译**

## 编译Linux内核

### 准备内核源码

```
wget https://mirrors.edge.kernel.org/pub/linux/kernel/v2.6/linux-2.6.26.tar.xz
```

> 或者使用北京外国语大学镜像源加速：
>
> ```
> wget https://mirrors.bfsu.edu.cn/kernel/v2.6/linux-2.6.26.tar.xz
> ```

解压

```
tar xf linux-2.6.26.tar.xz
```

由于官方的源码中有错误，直接编译会报错，因此需要打补丁

```
patch -p0 < patch-2.6.26
```

### 使用容器编译内核

生成默认配置文件

```
docker run --rm -v $(pwd)/linux-2.6.26:/src build-env ARCH=i386 defconfig
```

编译 bzImage 

```
docker run --rm -v $(pwd)/linux-2.6.26:/src build-env ARCH=i386 bzImage
```

（可选）如果需要对内核进行配置，可以使用菜单修改配置文件（注意使用 -it 参数启动交互）

```
docker run -it --rm -v $(pwd)/linux-2.6.26:/src build-env ARCH=i386 menuconfig
```

## 创建初始内存磁盘

### 准备 Busybox 源码

```
wget https://busybox.net/downloads/busybox-1.30.1.tar.bz2
```

> 或者使用**作者私人源**加速
>
> **此下载链接会为我带来流量费用，如果可以，请使用官方下载链接。**
>
> ```
> wget https://jklincn-source.oss-cn-hongkong.aliyuncs.com/busybox-1.30.1.tar.bz2
> ```

解压

```
tar xf busybox-1.30.1.tar.bz2
```

### 使用容器编译安装 Busybox

生成默认配置文件

```
docker run --rm -v $(pwd)/busybox-1.30.1:/src build-env defconfig
```

使用菜单修改配置文件（注意使用 -it 参数启动交互）

```
docker run -it --rm -v $(pwd)/busybox-1.30.1:/src build-env menuconfig
```

1. 选择静态链接

   ```
   Settings -> Build static binary（no share libs）-> Press 'y'
   ```

2. 关闭 job control

   ```
   Shells -> Job control -> Press 'n'
   ```

3. 保存设置退出界面

编译安装 Busybox

```
docker run --rm -v $(pwd)/busybox-1.30.1:/src build-env install
```

### 制作镜像

```
dd if=/dev/zero of=initrd.img count=1024 bs=4096
mkfs.ext2 initrd.img
```

### 创建字符设备

```
mkdir rootfs
sudo mount -o loop initrd.img rootfs
sudo mkdir rootfs/dev
sudo mknod rootfs/dev/console c 5 1
sudo mknod rootfs/dev/null c 1 3
sudo mknod rootfs/dev/ram b 1 0
```

### 拷贝 Busybox

```
sudo cp -r busybox-1.30.1/_install/* rootfs
sudo umount rootfs
```

## 在QEMU中运行内核

### 安装 QEMU

参见 [Download QEMU](https://www.qemu.org/download/#linux)

### 使用 QEMU 启动

```
qemu-system-i386 -nographic -kernel linux-2.6.26/arch/x86/boot/bzImage -initrd initrd.img -append "root=/dev/ram init=/bin/sh console=ttyS0"
```

如果成功，最后会输出如下信息，即可使用 busybox 中的系统常见程序（位于 /bin ）。

```
RAMDISK: ext2 filesystem found at block 0
RAMDISK: Loading 4096KiB [1 disk] into ram disk... done.
VFS: Mounted root (ext2 filesystem) readonly.
Freeing unused kernel memory: 240k freed
/ # 
```

### 虚拟机中可能遇见的问题

> Failed to execute /bin/sh.	Attempting defaults...
>
> Kernel panic - not syncing: No init found.	Try passing init= option to kernel.

此错误在虚拟机中比较常见，个人猜测是虚拟机中磁盘制作有问题。如果有人知道问题欢迎联系。

可以尝试个人已制作好的初始内存磁盘，步骤如下：

```
rm initrd.img
wget https://jklincn-source.oss-cn-hongkong.aliyuncs.com/initrd.img
```

再重新使用 QEMU 启动。