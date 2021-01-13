# Debugging Impala Minidumps
This project from impala

## 0. Init Breakpad
Downloading Python dependencie and toolchain dependencies and install.
```
# Init dependencies
$ ./init_deps.sh

# Quick script
# Get dump symbols in Breakpad's format
$ bin/dump_breakpad_symbols.sh

# Process the minidump file
$ bin/minidump_stackwalk.sh
```

## 1. Get Minidump
```bash
$ pidof impalad
26547 26466 26401
# or
$ ps aux | grep impalad
root      4374  0.0  0.0  12944   972 pts/0    S+   16:49   0:00 grep --color=auto impalad
impala   29645  1.0  3.0 2999416 231972 ?      Sl   16:17   0:20 /opt/cloudera/parcels/CDH-5.16.2-1.cdh5.16.2.p0.8/lib/impala/sbin-retail/impalad --flagfile=/run/cloudera-scm-agent/process/55-impala-IMPALAD/impala-conf/impalad_flags
impala   29652  0.0  0.1 197888 13556 ?        Sl   16:17   0:00 python2.7 /usr/lib/cmf/agent/build/env/bin/cmf-redactor /usr/lib/cmf/service/impala/impala.sh impalad impalad_flags false
$ kill -SIGUSR1 26547
$ ls logs/cluster/minidumps/impalad
5282c9d1-892e-3f43-6867e5f3-6134bc8f.dmp
```
## 2. Get dump symbols in Breakpad's format
### 2.1 Extracting from parcel package
If you obtained a minidump file from a host that had been installed using PARCEL packages, then you can you can use the script to dump the symbols like so:
```bash
$ bin/dump_breakpad_symbols.py -f /opt/clouduera/parcels/CDH/lib/impala/sbin-retail/impalad -d /tmp/syms
INFO:root:Processing binary file: /opt/cloudera/parcels/CDH/lib/impala/sbin-retail/impalad
```
### 2.2 Extracting from RPMs/DEBs
If you obtained a minidump file from a host that had been installed using RPM packages, then you will have to retrieve matching versions of the RPM package that is installed on the host and its corresponding debuginfo package. 

If your system was running CentOS 6 and Cloudera's CDH5.8.0, you would need these two files:

http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/5.8.0/RPMS/x86_64/impala-2.6.0+cdh5.8.0+0-1.cdh5.8.0.p0.111.el6.x86_64.rpm
http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/5.8.0/RPMS/x86_64/impala-debuginfo-2.6.0+cdh5.8.0+0-1.cdh5.8.0.p0.111.el6.x86_64.rpm

Then you can use the script to dump the symbols like so:
```bash
$ dump_breakpad_symbols.py -r impala-2.6.0+cdh5.8.0+0-1.cdh5.8.0.p0.111.el6.x86_64.rpm -s impala-debuginfo-2.6.0+cdh5.8.0+0-1.cdh5.8.0.p0.111.el6.x86_64.rpm -d /tmp/syms
INFO:root:Extracting: impala-2.6.0+cdh5.8.0+0-1.cdh5.8.0.p0.111.el6.x86_64.rpm
573966 blocks
INFO:root:Extracting: impala-debuginfo-2.6.0+cdh5.8.0+0-1.cdh5.8.0.p0.111.el6.x86_64.rpm
2590102 blocks
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/lib/libstdc++.so.6.0.20
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/lib/libkudu_client.so.0.1.0
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/lib/libstdc++.so.6
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/lib/libkudu_client.so.0
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/lib/libgcc_s.so.1
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/sbin-retail/libfesupport.so
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/sbin-retail/impalad
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/sbin-debug/libfesupport.so
INFO:root:Processing binary file: /tmp/tmpL5sAoP/usr/lib/impala/sbin-debug/impalad
```


## 3. Process the minidump file
Once you have extracted debug symbols into a folder you can use the minidump_stackwalk tool from Breakpad to resolve the symbols.
```bash
$ $IMPALA_TOOLCHAIN/breakpad-$IMPALA_BREAKPAD_VERSION/bin/minidump_stackwalk logs/cluster/minidumps/impalad/5282c9d1-892e-3f43-6867e5f3-6134bc8f.dmp /tmp/syms > /tmp/resolved.txt
```
The result should look like this:
```
Operating system: Linux
                  0.0.0 Linux 4.2.0-35-generic #40~14.04.1-Ubuntu SMP Fri Mar 18 16:37:35 UTC 2016 x86_64
CPU: amd64
     family 6 model 60 stepping 3
     1 CPU
GPU: UNKNOWN
Crash reason:  DUMP_REQUESTED
Crash address: 0x2845873
Process uptime: not available
Thread 0 (crashed)
 0  impalad!google_breakpad::ExceptionHandler::WriteMinidump [exception_handler.cc : 650 + 0xd]
    rax = 0x00007f499f5bbd38   rdx = 0x0000000000000000
    rcx = 0x0000000002845852   rbx = 0x0000000000000000
    rsi = 0x0000000000000001   rdi = 0x00007fff6bfe4488
    rbp = 0x00007fff6bfe4aa0   rsp = 0x00007fff6bfe43f0
     r8 = 0x0000000000000000    r9 = 0x00007fff6bfe4238
    r10 = 0x00007fff6bfe46c0   r11 = 0x00000000040f1f20
    r12 = 0x00007fff6bfe4a60   r13 = 0x00000000015bf605
    r14 = 0x0000000000000000   r15 = 0x0000000000000000
    rip = 0x0000000002845873
    Found by: given as instruction pointer in context
 1  impalad!google_breakpad::ExceptionHandler::WriteMinidump [exception_handler.cc : 621 + 0x8]
    rbx = 0x00007f499ef7e660   rbp = 0x00007fff6bfe4aa0
    rsp = 0x00007fff6bfe4a40   r12 = 0x00007fff6bfe4a60
    r13 = 0x00000000015bf605   r14 = 0x0000000000000000
    r15 = 0x0000000000000000   rip = 0x00000000028460cc
    Found by: call frame info
 2  impalad!impala::HandleSignal [minidump.cc : 93 + 0x1e]
    rbx = 0x0000000000000000   rbp = 0x00007fff6bfe4b70
    rsp = 0x00007fff6bfe4b60   r12 = 0x00007fff6bfe51e0
    r13 = 0x000000000b466170   r14 = 0x0000000000000000
    r15 = 0x0000000000000000   rip = 0x00000000015bf725
    Found by: call frame info
...
```

You can use the following command to see the stack
``` bash
$ grep -v = /tmp/resolved.txt | grep -v 'Found by' | less
Thread 119
 0  libpthread-2.23.so + 0xd360
 1  impalad!impala::io::DiskIoMgr::WorkLoop(impala::io::DiskIoMgr::DiskQueue*) [disk-io-mgr.cc : 977 + 0x5]
 2  impalad!impala::Thread::SuperviseThread(std::string const&, std::string const&, boost::function<void ()>, impala::ThreadDebugInfo const*, impala::Promise<long>*) [function_template.hpp : 767 + 0x7]
 3  impalad!boost::detail::thread_data<boost::_bi::bind_t<void, void (*)(std::string const&, std::string const&, boost::function<void ()>, impala::ThreadDebugInfo const*, impala::Promise<long>*), boost::_bi::list5<boost::_bi::value
<std::string>, boost::_bi::value<std::string>, boost::_bi::value<boost::function<void ()> >, boost::_bi::value<impala::ThreadDebugInfo*>, boost::_bi::value<impala::Promise<long>*> > > >::run() [bind.hpp : 525 + 0x6]
 4  impalad!thread_proxy + 0xda
 5  libpthread-2.23.so + 0x76ba
 6  libc-2.23.so + 0x10741d
```

## Refer
+ https://cwiki.apache.org/confluence/display/IMPALA/Debugging+Impala+Minidumps
+ https://blog.csdn.net/huang_quanlong/article/details/103000348