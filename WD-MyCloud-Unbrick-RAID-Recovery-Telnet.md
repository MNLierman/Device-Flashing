
## WD MyCloud Unbrick RAID Recovery Telnet
I recently ran into a few of these old WD MyCloud devices that a client was using for some pretty important data. These are the steps I took along with some suggestions and additional explanation how other sencarios and how you could handle them when recovering these devices.
(link here to the original instructions, link here to the recovery zip)

1. MyCloud not booting -> The very first thing you need to do is plug your PC/laptop into the MyCloud directly via ethernet and start a DHCP server and continuous ping prompt with the magic packet targeting the MAC address. The needed files are in the link above and I will upload them here soon.
-- Here's how this works: The MyCloud tries for 3-5 seconds on bootup to see a DHCP server on the network with the IP range of 192.168.0.1. I actually haven't tested other ranges but you could potentially serve it an unused IP range from your primary network, like x.x.x.250-253 or something which I've never seen any router serve out before, so that would be a safe range.
2. Run telnet script to serve the MyCloud a 200MB recovery img with busybox. Then telnet again, and run two commands. Default IP is 192.168.0.4, username root, password mycloud
3. Start the magic packet ping with the MAC address inputted . With ping running, start DHCP server. 
4. Get it on your primary network (if nothing but 192.168.x.x works which could be the case, and this is what I did.) Set static IP: "ifconfig eth0 192.168.1.200 netmask 255.255.255.0 up && route add default gw 192.168.1.1 && ifconfig eth0 down && ifconfig eth0 up" **Obviously replace with your IP.**
5. Start FTP server: "tcpsvd -vE 0.0.0.0 21 ftpd /" From there you have an ftp server running on the MC running on your preferred network and don't need to keep your desktop in a limbo mode, making it very easy and versatile recovery environment. You can mount the RAID using MDADM and check the logs if you are troubleshooting an issue with booting, or run ddrescue once mounting the RAID.
This may get renamed later or reorganized, but for now, this is a place where
6. If you need to recovery the data, use MDADM and rebuild the RAID or force it to attempt to recover the structure that it can. Then plug in a thumb drive and install Entware to the thumb drive, bind the /opt to the entware directory of the mount location of the thumbdrive. Now you have a package installer, install ddrescue, and recover the DATA to a external SSD. These are the steps I took. I actaully use DD as well. All of this took a few hours to run.
-- You could also slave the HDD to a workhorse, but if you don't have a machine that can read Linux and don't have a "workhorse" then you're stuck using the busybox emergency OS to recover your data or unbrick your device.

***I will Continue Adding To This Repo With More Helpful Information. I May Even Attempt To Rebuild The Source Of The Kernel For Debian 12, If I Get The Time. We'Ll See.***
