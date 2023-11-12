#!/bin/bash
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

addUser(){
	read -rp "请输入用户名：" username
	
	groupadd "${username}"
	useradd -g "${username}" -m -d "/home/${username}" "${username}"
	
	read -rp "请输入密码【默认随机】：" password
    [[ -z $password ]] && password=$(date +%s%N | md5sum | cut -c 1-16)
	echo "${username}:{$password}" | chpasswd
	
	if [ $? -ne 0 ]; then
		echo "设置密码失败！"
		exit 1
	fi
	
	# 修改sudoer
	sed -i "/root.*ALL/a\\${username} ALL=(ALL) NOPASSWD:ALL" /etc/sudoers
	
	# 写到临时文件
	cat <<EOF > users.txt
用户名：$username
密码：$password
EOF
}

changeSsh(){
	if [ -f /etc/ssh/sshd_config ]; then
		# 端口修改
		read -rp "请输入ssh端口【默认随机】：" sshport
		[[ -z $sshport ]] && sshport=$(shuf -i 10000-65535 -n 1)
		until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$sshport") ]]; do
			if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$sshport") ]]; then
				echo -e "${sshport} 端口已经被其他程序占用，请更换端口重试！"
				read -rp "请输入ssh端口【默认随机】：" sshport
				[[ -z $sshport ]] && sshport=$(shuf -i 10000-65535 -n 1)
			fi
		done
		
		sudo sed -i "s/^.*Port.*/Port ${sshport}/g" /etc/ssh/sshd_config
		sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
		sudo service ssh restart
	else
		echo "找不到SSH配置文件，请手动启用Root登录和密码验证。"
	fi
	
	cat <<EOF > sshinfo.txt
ssh端口：$sshport
EOF
}

main(){
	addUser
	changeSsh
	
	echo -e "${YELLOW}"
	cat users.txt
	rm users.txt
	cat sshinfo.txt
	rm sshinfo.txt
	echo -e "${PLAIN}"
}

main