# Первое и основное. Сбрасываем устройство в состоянии пусто абсолютно. Подтверждаем выполнение через Y.

/system reset-configuration no-defaults=yes skip-backup=yes

# Создадим запись администратора и подлючимся через него далее удалим дефолтного администратора

/user add name=ADMINISTRATOR password=PASSWORD group=full
/user remove admin

# Либо же изменим пароль на существующей записи админа

/user set [find name=admin] password=PASSWORD

# Создаем бридж для наших интерфейсов. Прибиваем mac адрес. Для домашнего роутера включать работу vlan не нужно, но вы можете.
# Замените mac адрес на любой свой.
# Прибивать mac на всех устройствах обязательно. В противном случае при dhcp может сменится IP и какой нибудь ваш мониторинг свалит в бесконечность.
# Например тут мы это сделаем используя скрипт по поиску настоящего mac адреса eth2. Eth1 куда более полезен как Uplink со свои PoE in.

/interface bridge
add admin-mac= [:put [/interface ethernet get [/interface ethernet find default-name=ether2] mac-address ]] auto-mac=no name=bridge-lan protocol-mode=none

# Добавим интерфейсы в бридж.

/interface bridge port
add bridge=bridge-lan interface= [:put [/interface ethernet get [/interface ethernet find default-name=ether2] name]]
add bridge=bridge-lan interface= [:put [/interface wireless get [/interface wireless find default-name=ether3] name]]
add bridge=bridge-lan interface= [:put [/interface ethernet get [/interface ethernet find default-name=ether4] name]]
add bridge=bridge-lan interface= [:put [/interface wireless get [/interface wireless find default-name=ether5] name]]
add bridge=bridge-lan interface= [:put [/interface ethernet get [/interface ethernet find default-name=wlan1] name]]
add bridge=bridge-lan interface= [:put [/interface wireless get [/interface wireless find default-name=wlan2] name]]

# Назначем DHCP Client на необходимы нам интерфейс. С которого хотим получать интернет.
# Можно указать дополнительные параметры хотим ли мы получить DNS и NTP провайдера по DHCP или быть может на этом устройстве мы укажем свои.
# Так же есть возможность создать маршрут динамически и указать его приоритет.

/ip dhcp-client
add disabled=no interface=ether1 use-peer-dns=no use-peer-ntp=no

# Назначим IP для нашей локальной сети. На вкус и цвет так сказать.

/ip address
add address=192.168.69.1/24 interface=bridge-lan network=192.168.69.0

# Создадим DHCP сервер. Нужно же как-то раздавать адреса в локальной сети. Можно указать сторонний NTP или DNS.
# Так же можно указать наш GW как NTP и DNS для локальной сети. Так немного быстрее будет работать, так как DNS будет кешироваться на роутере.

/ip dhcp-server network
add address=192.168.69.0/24 dns-server=62.76.76.62,62.76.62.76 ntp-server=194.190.168.1 gateway=192.168.69.1

# Или

/ip dhcp-server network
add address=192.168.69.0/24 dns-server=192.168.69.1 ntp-server=192.168.69.1 gateway=192.168.69.1

# Нужно задать диапазон раздаваемых адресов нашим DHCP сервером.

/ip pool
add name=pool-dhcp ranges=192.168.69.2-192.168.69.254

# Ну и наконец после предварительно созданных адресных параметров сетапим сервак.
# Время аренды адреса лучше всего задавать на день 12h или неделю 5d для частных сетей. Для хонтспотов уже отдельная история там можно и 15m задать.

/ip dhcp-server
add add-arp=yes address-pool=pool-dhcp disabled=no interface=bridge-lan lease-time=12h name=dhcp-lan

# Привяжем некоторые IP адреса для определенных mac адресов. Так можно будет осуществить менеджмент на базе правил маршрутизации ваших устройств.
# Так же сразу в DHCP Leases зададим динамический лист IP адресов для устройств.

/ip dhcp-server lease
add address=192.168.69.250 address-lists="To VPN" client-id=1:11:11:11:11:11:11 comment=phone mac-address=11:11:11:11:11:11 server=dhcp-lan
add address=192.168.69.253 address-lists="To VPN" client-id=1:33:33:33:33:33:33 comment=printer mac-address=33:33:33:33:33:33 server=dhcp-lan
add address=192.168.101.248 client-id=1:44:44:44:44:44:44 comment=pc1 mac-address=44:44:44:44:44:44 server=dhcp-lan
add address=192.168.101.247 client-id=1:55:55:55:55:55:55 comment=pc2 mac-address=55:55:55:55:55:55 server=dhcp-lan

# Добавим адреса глобальных DNS для самого роутера. Так же можно расширить размер кэша.

/ip dns
set allow-remote-requests=yes cache-size=10240KiB servers=62.76.76.62,62.76.62.76

# Допустим теперь мы хотим ограничить скорость для устройства или для всей сети.
# Зададим типы очередей. Думаю принцип понятен.

/queue type
add kind=pcq name=pcq-download-10M pcq-classifier=dst-address pcq-rate=10M
add kind=pcq name=pcq-upload-10M pcq-classifier=src-address pcq-rate=10M
add kind=pcq name=pcq-download-15M pcq-classifier=dst-address pcq-rate=15M
add kind=pcq name=pcq-upload-15M pcq-classifier=src-address pcq-rate=15M
add kind=pcq name=pcq-download-20M pcq-classifier=dst-address pcq-rate=20M
add kind=pcq name=pcq-upload-20M pcq-classifier=src-address pcq-rate=20M
add kind=pcq name=pcq-download-30M pcq-classifier=dst-address pcq-rate=30M
add kind=pcq name=pcq-upload-30M pcq-classifier=src-address pcq-rate=30M
add kind=pcq name=pcq-download-50M pcq-classifier=dst-address pcq-rate=50M
add kind=pcq name=pcq-upload-50M pcq-classifier=src-address pcq-rate=50M

# Создадим правило шейпера в котором Загрузка и Отдача всей сети будет 100Мбит на 100Мбит.
# Так же добавим в правило то что мы будем ограничивать по 50Мбит на устройство.

/queue simple
add disabled=yes max-limit=100M/100M name=LAN priority=1/1 queue=pcq-upload-50M/pcq-download-50M target=192.168.69.0/24

# Либо создадим правило без ограничения по скорости. Простая сортировка и приоритезация всей подсети.

/queue simple
add name=LAN priority=1/1 queue=pcq-upload-default/pcq-download-default target=192.168.69.0/24

# Добавляем те интерфейс листы с которыми мы собираемся выстраивать менеджмент. Для примера.

/interface list
add name=WAN
add name=LAN
add name=MANAGEMENT
add name=PUBLIC
add name=VPN

# Добавляем интерфейсы в необходимые нам листы.

/interface list member
add interface=bridge-lan list=LAN
add interface=ether1 list=WAN

# Создаем профили безопасности для Wi-Fi сетей. Отдельный, так правильнее всего. Не нужно трогать дефолтный.

/interface wireless security-profiles
add authentication-types=wpa2-psk mode=dynamic-keys name=WPA2-PSK supplicant-identity="" wpa2-pre-shared-key=WIFIPASSWORD

# Кофигурируем имеющиеся wlan1 2G и wlan2 5G интерфейсы. Максимально возможный вариант 802.11 ac. Страна я выбрал russia3.
# Самое важное грамотно выбирать частоту и ширину вашего канала, а так же то как и в какую сторону он будет расширяться.
# Можно воспользоваться утилитой. Покажет список поддерживаемых и разрешенных каналов.

/interface wireless info allowed-channels wlan1
/interface wireless info allowed-channels wlan2

/interface wireless info country-info russia4

# Для 5ГГц я взял начальный 36 канал 5180Гц, при ширине в 80 и расширении Ceee это будет 42 канал, который займет 36,40,44,48 каналы от 5180Гц до 5240Гц.
# Для 2,4Ггц все очень просто можно использовать только 1, 6 и 11 каналы. Единственный способ избегать помехи и сохранить хоть какое-то качество связи.
# Двойка нужна не для скорости, не стоит изобретать велосипед. Любое устройство само переключится на пятерку. В примере канал 11 частотой 2462Гц.
# Обязательно включим полезную функцию WMM support. Задаем любое имя сети которое может понравится. SSID так же можно сделать скрытым.
# Всегда смеялся с этих disabled=no. Вполне нормально задать для 2,4 и 5 одно имя, есть легенда что сильно облегчает жизнь.

/interface wireless
set [ find default-name=wlan1 ] band=2ghz-onlyn country=russia3 disabled=no distance=indoors frequency=2462 installation=indoor mode=ap-bridge security-profile=WPA2-PSK ssid=WIFINAME wireless-protocol=802.11 wmm-support=enabled wps-mode=disabled
set [ find default-name=wlan2 ] band=5ghz-onlyac channel-width=20/40/80mhz-Ceee country=russia3 disabled=no distance=indoors installation=indoor mode=ap-bridge security-profile=WPA2-PSK ssid=WIFINAME wireless-protocol=802.11 wmm-support=enabled wps-mode=disabled

# Я использую 802.11, другие протоколы мне не надо.

/interface wireless nstreme
set wlan1 enable-polling=no
set wlan2 enable-polling=no

# Допустим мы настроили все адреса локальной сети. Теперь пора разобраться с самым сложным и главным этапом.
# Великий и ужасный firewall который почему-то никто не умеет настраивать.
# В последней строчке добавлено правило разрешающее подключение извне для проброшенных портов через dstnat. Не путать с netmap.

/ip firewall filter
add action=accept chain=input comment="Accept Established/Related" connection-state=established,related in-interface=ether1
add action=drop chain=input comment="Drop Invalid" connection-state=invalid in-interface=ether1
add action=accept chain=input comment="Accept ICMP" protocol=icmp
add action=accept chain=input comment="Accept DNS" dst-port=53 protocol=udp
add action=accept chain=input comment="Accept DNS" dst-port=53 protocol=tcp
add action=accept chain=input comment="Accept NTP" dst-port=123 protocol=udp
add action=accept chain=input comment="Accept NTP" dst-port=123 protocol=tcp
add action=drop chain=input comment="Drop All" in-interface=ether1
add action=accept chain=forward comment="Accept Established/Related" connection-state=established,related in-interface=ether1
add action=accept chain=forward comment="Accept Output" out-interface=ether1
add action=drop chain=forward comment="Drop Invalid" connection-state=invalid in-interface=ether1
add action=drop chain=forward comment="Drop all from WAN not DSTNATed" connection-nat-state=!dstnat connection-state=new in-interface=ether1

# Обычно после таких движений может быть полезным включить upnp. Программы на девайсах будут сами прибивать себе порты в NAT.
# Все просто, указываем внешний и внутренний интерфейс.

/ip upnp interfaces
add interface=bridge-lan type=internal
add interface=ether1 type=external
/ip upnp
set enabled=yes

# Правило подмены адресов для интернета и для наших VPN. Так как адреса динамические и там и там мы задаем masquerade.
# Не нужно пытаться что-то изобретать через src-nat, он для статики.

/ip firewall nat
add action=masquerade chain=srcnat comment=WAN-out out-interface=ether1
add action=masquerade chain=srcnat comment=VPN-out out-interface-list=VPN

# Просто насыплю тут горку адресных листов, потому что могу.

/ip firewall address-list
add address=google.com list="G Suite"
add address=gmail.com list="G Suite"
add address=login.microsoftonline.com list="Microsoft Office 365"
add address=login.microsoft.com list="Microsoft Office 365"
add address=login.windows.net list="Microsoft Office 365"
add address=192.168.69.0/24 list="LAN IP"
add address=224.0.0.0/4 list=MulticastAll
add list=none
add address=0.0.0.0/0 list=all
add address=224.0.0.1 list=MulticastAllHosts
add address=224.0.0.2 list=MulticastAllRouters
add address=224.0.0.5-224.0.0.6 list=MulticastOSPF
add address=224.0.0.10 list=MulticastEIGRP
add address=224.0.0.251 list=MulticastBonjour

# Можно указать адреса доступа сервисов роутера а так же поменять их порт.
# Указываем нашу локальную сеть. Так же можно отключить что не нравится.
# Допустим мне нужно только ssh и winbox.

/ip service
set telnet address=192.168.69.0/24 disabled=yes
set ftp address=192.168.69.0/24 disabled=yes
set www address=192.168.69.0/24 disabled=yes
set ssh address=192.168.69.0/24 port=2222
set www-ssl address=192.168.69.0/24
set api address=192.168.69.0/24 disabled=yes
set winbox address=192.168.69.0/24 port=8888
set api-ssl address=192.168.69.0/24 disabled=yes

# Сконфигурируем службу времени.

/system ntp client
set enabled=yes primary-ntp=194.190.168.1 secondary-ntp=176.126.44.214
/system ntp server
set broadcast=yes enabled=yes multicast=yes
/system clock
set time-zone-name=Europe/Moscow

# Укажем hostname.

/system identity
set name=mt-hap-ac2

# Допустим мы хотим чтобы у нас работал L2TP+IPSec клиент в офис к такому же MikroTik.
# Сразу же добавим динамические листы интерфейсов и адресов.
# Остальные параметры нужно уточнять в частном случае.

/ppp profile
add address-list="VPN Servers IP" change-tcp-mss=yes interface-list=VPN name=Client-L2TP+IPSec only-one=yes use-encryption=required use-mpls=no

# Создадим интерфейсы клиенты для VPN. Размер mtu должен быть одинаков для двух сторон.
# Так же нужно учитывать то чтобы мы пролезали пакетами через NAT провайдера и так далее.
# Аутентификаия выбрана mschap v2 на двух сторонах.
# Интересный факт Windows почему-то выбирал 1400 на тестах подключений. Так что возьмем его.
# В полях ipsec-secret, password, user берем свои значения.

/interface l2tp-client
add allow=mschap2 connect-to=3.3.3.3 disabled=no ipsec-secret=ipsecsecret keepalive-timeout=30 max-mru=1400 max-mtu=1400 name=l2tp-out-server1 password=password1 profile=Client-L2TP+IPSec use-ipsec=yes user=user1
add allow=mschap2 connect-to=5.5.5.5 disabled=no ipsec-secret=ipsecsecret keepalive-timeout=30 max-mru=1400 max-mtu=1400 name=l2tp-out-server2 password=password2 profile=Client-L2TP+IPSec use-ipsec=yes user=user2

# Добавим маршруты для vpn сетей. Допустим server1 имеет тунельный ip 10.10.10.1  а server2 имеет тунельный ip 10.22.23.1
# И под эти маршруты мы создадим отдельный таблицы маршрутизации vpn-1 и vpn-2.

/ip route
add distance=1 gateway=10.10.10.1 routing-mark=vpn-1
add distance=1 gateway=10.22.33.1 routing-mark=vpn-2

# Допустим мы хотим чтобы наши железки бегали в интернет и к ресурсам компании только через IP адрес компании.
# Да это тот самый адрес лист что мы динамически задали для рабочих устройств.

/ip firewall mangle
add action=mark-routing chain=prerouting disabled=yes dst-address-list="!LAN IP" new-routing-mark=vpn-1 passthrough=yes src-address-list="To VPN"

# Можем так же включить simple network management monitoring.
# Можно будет графики красивые рисовать.

/snmp
set contact=youremailhere enabled=yes location=locationaddress trap-generators=interfaces trap-version=2

# Это чисто приколюшка чтобы в мобильном приложении MikroTik показывало графики красивые.

/interface detect-internet
set detect-interface-list=WAN internet-interface-list=WAN lan-interface-list=LAN wan-interface-list=WAN

# Автовыборр частоты роутера. Можно конечно и занизить чтобы не грелся.

/system routerboard settings
set cpu-frequency=auto

# Ограничиваем интерфейсы где будем светится всякими LLDP и пр. То собственно почему мы видим MikroTik в Winbox и не только.

/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
/ip neighbor discovery-settings
set discover-interface-list=LAN
/ip smb
set allow-guests=no

# Активируем утилиту RoMON. Если необходимо

/tool romon
set enabled=yes id= [:put [/interface bridge get bridge-lan admin-mac]]

# Лучше включить эту галочку, она позволит вам автоматически загрузить прошивку в RouterBOARD после обновления и перезагрузки роутера чтобы 

/system routerboard settings
set auto-upgrade=yes

# Обновляемся. Настоятельно рекомендую использовать только long-term ветку обновлений, меньше багов больше надежность.
# Команды выполняем поочередно

/system package update
set channel=long-term
check-for-updates
download
install

# К примеру можно добавить скрипт на автоматическую перезагрузку роутера в 4 утра.

/system scheduler
add interval=1d name=autoreboot on-event="/system reboot" policy=reboot start-date=jan/01/2020 start-time=04:00:00
