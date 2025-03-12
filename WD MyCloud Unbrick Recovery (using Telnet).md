
### Introduction: WD MyCloud (All Generations) Unbrick & Data Recovery
#### How To Recover Data from WD MyCloud (Older versions, including RAID 1-bay or 2-bay)
Recent client in which the RAID on their MyCloud crashed, all MyClouds are configured with hardware or software RAIDs. Essentially, their MyCloud was bricked, and since RAIDs can be complicated and sometimes require enourmous amounts of time, that can make it even more frustrating for people. If you lost the data, a data recovery center may charge you thousands. To note, it may seem obious, but WD does not support the older MyClouds and the Debian 7 OS anymore. Thankfully there is some information out there on reflashing and unbricking the MyCloud devices, thanks to some of that information, I have built onto that and found my own utilties, tricks, and tools to make this a much easier process. For this client, it turned out to be a OS crash, but these steps work for any scenario on the WD My Clouds, gen 1, gen 2, and gen 3.

Alternatively, for data recovery: You could take apart the MyCloud, as if the HDD connector is not soldered to the board, which almost all manufacturers have been doing for 8-10 years now, they you may be able to remove the HDD, slave it to a workhorse/secondary machine that has Linux or data recovery software that can rebuild a foreign Linux RAID. I believe the filesystem on the HDD would still be Ext3/Ext4 and Windows doesn't work well with this, and there is (as of 2024) still limited Ext4 support in WSL2. This is why I choose to do it the following way. 

<br/>

### Steps / How It Works
I recently ran into a few of these old WD MyCloud devices that a client was using for some pretty important data. These are the steps I took along with some suggestions and additional explanation how other sencarios and how you could handle them when recovering these devices.
(link here to the original instructions, link here to the recovery zip)

**What You Need & Suggestions**
* SSH/Telnet appliation: Putty or KiTTY; FTP/SFTP application: Suggestion - WinSCP
* Thumbdrive and Ext SSD (for data recovery)

**Steps:**

1. MyCloud not booting -> 1st step, plug your PC/laptop into the MyCloud directly via ethernet, from the tools zip, and start a DHCP server window and continuous ping with the magic packet targeting the MAC address. The needed files are in the link above and I will upload them here soon.
-- How this works: The MyCloud tries for 3-5 seconds on bootup to see a DHCP server on the network with the IP range of 192.168.0.1. I actually haven't tested other ranges but you could potentially serve it an unused IP range from your primary network, like x.x.x.250-253 or something which I've never seen any router serve out before, so that would be a safe range.
2. Run telnet script to serve the MyCloud a 200MB recovery img with busybox.
3. Open 2 or 3 telnet windows using Putty or Kitty on the IP of the MyCloud port 23 and connection. Default should be 192.168.0.4, username root, password mycloud.
4. Get it on your primary network. Set static IP: "ifconfig eth0 192.168.1.200 netmask 255.255.255.0 up && route add default gw 192.168.1.1 && ifconfig eth0 down && ifconfig eth0 up" **Obviously replace with your IP.** You could also change the DHCP server script to server the MyCloud an unused range within your router's DHCP pool if you want, and that should work. I choose to use ifconfig, you could even do both just to be sure.
5. Start FTP server: "tcpsvd -vE 0.0.0.0 21 ftpd / &" The & should allow it to keep the command running and you can Ctrl-C to get your input back on the window and reuse the window.
6. Open FTP file manager and connect to port 21, username root, password mycloud, same as above. You now have an easy and versatile recovery environment to recovery data, create an image of the rootfs, kernel, or config partitions to see what you did wrong, and copy logs to see why it won't boot. 

<br/>

### Mounting the RAID
#### Now that you have your environment setup, you need to mount the partitions and get the RAID online, all you will be able to see up to this point in Kitty or WinSCP is the recovery environment. I will be adding to and reroganizing this guide to make it easier to understand as I am working on a recovery project Oct 2024.
Thank You: To Foxie, a public forums user who posted a lot of research he discovered about the MyClouds, this would have been so much more difficult without that. 

**Info about the MyCloud Partitions & RAIDs:** The original WD firmware sets up (and requires) 8 partitions. Each group is RAID1 mirrored. It was on the forums that the other partitions are not used, and this does not appear to be accurate. When the MDADM driver loads, the system will use both SDA1 and 2 for rootfs, both SDA5 & 6 for kernel, and 7 & 8 for config. If one partition in the flash memory becomees corrupted or won't boot, it's possible that the RAID driver will boot the other partition, or attempt to recover from there error. It's also possible to, if it doesn't already, tell the driver and kernel to boot one partition and take the other offiline for fsck. Given this is a RAID1 and given these are mechanical HDDs, it would be hard to say that default driver does not failover. There would be no other purpose. Now whether it only does some of these things, all of them, or none of them, I'm not sure anyone knows this but WD, but they are used. RAID1 mirroring also allows higher read speed, but write speed could be reduced. The DATA partition of the single-bay models is NOT RAID mirrored.

**Mounting rootfs (Debian OS)**

You can mount the OS RAID using MDADM and check the logs if you are troubleshooting an issue with booting, or run ddrescue once mounting the RAID. <br/>
Bring up rootfs RAID: md0: mdadm --create --force /dev/md0 --verbose --metadata=0.90 --raid-devices=2 --level=raid1 --run /dev/sda1 /dev/sda2<br/>
Mount rootfs RAID: mkdir /mnt/md0; mount /dev/md0 /mnt/md0<br/>

If you are unbricking your rootfs and you you previously flashed your MyCloud utilizing only sda1, and you want to fix that, you will need to bring that up first, save your broken image for research (if you want), format sda1, take it down, bring up the second partition, format it, take it down, and then bring up a RAID1 with both, format it, and image it. Or you could also opt to image them separately.

Bring up only sda1 to md0: mdadm --create --force /dev/md0 --verbose --metadata=0.90 --raid-devices=**1** --level=raid1 --run **/dev/sda1**<br/>
Bring up both: md0: mdadm --create --force /dev/md0 --verbose --metadata=0.90 --raid-devices=2 --level=raid1 --run /dev/sda1 /dev/sda2<br/>
Mount it: mkdir /mnt/md0; mount /dev/md0 /mnt/md0<br/>

**Mounting DATA (where shares ares located)**

mkdir /mnt/sda4; mount /dev/sda4 /mnt/sda4

**Unmount rootfs after inspecting**<br/>
(perhaps you've finished collecting necessary logs from /var/log)<br/>

umount /mnt/md0, and if that fails then,<br/>
    >  fuser -km /mnt/md0 && umount /mnt/md0<br/>

**Sending new image or backup img**

In 1st window, sends img: dd if=/mnt/sda4/Shares/yourrootfs.img of=/dev/md0 <br/>
In 2nd window, refreshes every second: watch -n 1 kill -USR1 $(pidof dd)<br/>

<br/>

### Performing Data Recovery
If you need to recovery the data, use MDADM and rebuild the RAID or force it to attempt to recover the structure that it can. Then, if you are recovering data, it's important that you plugin a drive large enough to recover the data to, you can't recover the data over the network as the recovery environment will not allow you to enable Samba (required for network shares). From there, you will want to create the basic directory structure for installing a package manager, such as Entware, binding /Opt to /tmp/opt and bind /tmp/opt to /tmp/mnt/(USBLOCATION)/entware to /tmp/opt, and /dev/(USBLOCATION) to /tmp/mnt/(USBLOCATION). I will upload a sample script at some point soon, this sounds complicated but it's not. The reason this is necessary is that / is read-only in recovery as it's mounted in memory. /tmp is mounted as read-write in memory but it's limited to somewhere around 50-100 mb. By plugging in a ext SSD or thumb drive, you can mount/bind a package manager over read-only directories such as /opt and install live packages and data recovery tools to your ext SSD. This your best bet in circumstances like this, short from taking apart the MyCloud, hoping it's not soldering, and trying to rebuild the RAID on your own PC. 

Once you have Entware installed, you can also find other binaries that don't require a lot of dependencies, without using the package store. You can search using "site:github.com" for applications that are compiled for armv7-mo and transfer them to /opt/bin. You could even donate a thumbdrive to Entware if you are an IT technician and run into future embeddeed systems that you need to diagnose/troubleshoot/repair, as Entware is compatible with all arm processesors. From routers, to PCs, anything. You can even install SSH, and if you have any Entware thumbdrive, using the command sshd start will start the sshd server using the port number and loaded certs you have. I would recommend doing this through Dropbear but you can also installed OpenSSH-Server from Entware, though it often requires additional setup, so Dropbear would be easier. 

***I will continue adding to this repo with more helpful information. I may even attempt to rebuild the kernel for the MyClouds gen 1 and 2 for Debian 11 or 12 support, if I have enough time.***
