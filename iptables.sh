#!/bin/sh

out_iface="eth0"
server_IP="1.2.3.4"
subnet="192.168.42.0/24"
 
# strongswan
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
 
# Moved to /etc/sysctl.conf: net.ipv4.ip_forward=1
# 打开网卡转发功能。要把客户端的请求转发到公网网卡
# echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s ${subnet} -o ${out_iface} -j MASQUERADE
# 允许转发
iptables -A FORWARD -s ${subnet} -j ACCEPT
 
[ -r chnroute.txt ] || curl 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' | grep ipv4 | grep CN | awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > chnroute.txt
 
iptables -t nat -N SHADOWSOCKS
 
iptables -t nat -A SHADOWSOCKS -d $server_IP -j RETURN
 
# 内网网段
iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN
 
# 创建ipset列表
#ipset -exist create gfwlist hash:net
ipset -exist create chnroute hash:net
cat chnroute.txt | sudo xargs -I ip ipset -exist add chnroute ip
 
# gfwlist 走ss转发
#iptables -t nat -A SHADOWSOCKS -m set --match-set gfwlist dst -p tcp  -j REDIRECT --to-ports 1080
 
# 国内ip表直连
iptables -t nat -A SHADOWSOCKS -m set --match-set chnroute dst -p tcp -j REDIRECT --to-ports 1080
# 其他连接走ss转发
iptables -t nat -A SHADOWSOCKS -p tcp  -j RETURN
 
iptables -t nat -A PREROUTING -s ${subnet} -p tcp -j SHADOWSOCKS
 
# ss-redir
iptables -A INPUT -p tcp -s ${subnet} --dport 1080 -j ACCEPT
iptables -A INPUT -p tcp --dport 1080 -j DROP
