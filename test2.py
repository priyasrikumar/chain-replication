#!/usr/bin/env python

from random import getrandbits

from select import poll, POLLIN
from subprocess import Popen, PIPE
from time import sleep, time 
import argparse

from mininet.cli import CLI
from mininet.net import Mininet
from mininet.node import Node, OVSController
from mininet.link import TCLink
from mininet.topo import Topo
from mininet.log import info, setLogLevel

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='A testing program.')
    parser.add_argument("config", help="Config file for tester.")
    args = parser.parse_args()

    topo = Topo()

    # create a host for the tester and switch for the tester
    # hook them up together
    topo.addHost('tester')
    topo.addSwitch('swt', dpid='50')
    topo.addLink('tester', 'swt', bw=1000)

    # create a central switch, connect tester switch to the
    # central switch
    topo.addSwitch('s1')
    topo.addLink('swt', 's1', bw=1000)

    config = open('{0}'.format(args.config), 'r')
    configLines = config.readlines()
    configLines = [line.strip() for line in configLines]
    numServers = int((configLines[0])[configLines[0].index('=')+1:])
    numClients = int((configLines[1])[configLines[1].index('=')+1:])
    numBackups = int((configLines[2])[configLines[2].index('=')+1:]) 

    # create servers for chain nodes and hook them up to switches
    # hook the server switches to the central switch
    for s in range(1, numServers + 1):
        topo.addHost('hs{0}'.format(s))
        topo.addSwitch('sws{0}'.format(s), dpid='{0}'.format(100+s))
        topo.addLink('hs{0}'.format(s), 'sws{0}'.format(s), bw=1000)
        topo.addLink('sws{0}'.format(s), 's1', bw=1000)

    # create servers for client nodes and hook them up to switches
    # hook the server switches to the central switch
    for c in range(1, numClients + 1):
        topo.addHost('hc{0}'.format(c))
        topo.addSwitch('swc{0}'.format(c), dpid='{0}'.format(200+s))
        topo.addLink('hc{0}'.format(c), 'swc{0}'.format(c), bw=1000)
        topo.addLink('swc{0}'.format(c), 's1', bw=1000) 

    # create servers for backup nodes and hook them up to switches
    # hook the server switches to the central switch
    for b in range (1, numBackups + 1):
        topo.addHost('hb{0}'.format(b))
        topo.addSwitch('swb{0}'.format(b), dpid='{0}'.format(300+s))
        topo.addLink('hb{0}'.format(b), 'swb{0}'.format(b), bw=1000)
        topo.addLink('swb{0}'.format(b), 's1', bw=1000)

    duration = int((configLines[3])[configLines[3].index('=')+1:])
    ratio = float((configLines[4])[configLines[4].index('=')+1:])
    lbound = int((configLines[5])[configLines[5].index('=')+1:])
    rbound = int((configLines[6])[configLines[6].index('=')+1:])
    failures = ((configLines[7])[configLines[7].index('=')+1:]).split()

    stride = int((rbound - lbound) / (numClients + numBackups))

    setLogLevel('info')
    net = Mininet(topo=topo, link=TCLink, autoSetMacs=True, autoStaticArp=True, controller=OVSController("mnctl"))

    net.start()
#    CLI(net)
    serverHosts = []
    clientHosts = []
    backupHosts = []

    serverString = ''
    clientString = ''
    backupString = ''
    failureString = ''
    for i in range(1, numServers + 1):
        serverHosts.append(net.get('hs{0}'.format(i)))
        serverString += '-server {0}:10000 '.format(net.get('hs{0}'.format(i)).IP())
    for i in range(1, numClients + 1):
        clientHosts.append(net.get('hc{0}'.format(i)))
        clientString += '-client {0}:10000 '.format(net.get('hc{0}'.format(i)).IP())
    for i in range(1, numBackups + 1):
        backupHosts.append(net.get('hb{0}'.format(i)))
        backupString += '-backup {0}:10000 '.format(net.get('hb{0}'.format(i)).IP())
    for f in failures:
        failureString += '-failure {0} '.format(f)

    print('sending command to starting server at {0}'.format(serverHosts[0].IP()))
    serverHosts[0].sendCmd('_build/default/chainnode_src/chain_bin/chainnode.exe -ip {0} -port 10000 -is-init'.format(serverHosts[0].IP()))

    for serverHost in serverHosts[1:]:
        sleep(2)
        print('sending command to server at {0}'.format(serverHost.IP()))
        serverHost.sendCmd('_build/default/chainnode_src/chain_bin/chainnode.exe -ip {0} -port 10000 -current-config {1}:10002'.format(serverHost.IP(), serverHosts[0].IP()))

    currentConfigString = ''
    for serverHost in reversed(serverHosts):
        currentConfigString += '-current-config {0}:10002 '.format(serverHost.IP())

    for backupHost in backupHosts:
        sleep(2)
        print('sending command to backup at {0}'.format(backupHost.IP()))
        print(currentConfigString)
        backupHost.sendCmd('_build/default/chainnode_src/chain_bin/chainnode.exe -ip {0} -port 10000 -current-config {1} -is-test'.format(backupHost.IP(), currentConfigString))

    for i, clientHost in enumerate(clientHosts):
        lbound1 = str(int(lbound + (i * stride)))
        rbound1 = str(int(lbound + ((i + 1) * stride) - 1))
        print('sending command to client at {0}'.format(clientHost.IP()))
        clientHost.sendCmd('_build/default/chainclient_src/client_bin/chainclient.exe -ip {0} -port 10000 -duration {1} -lbound {2} -rbound {3} -ratio {4} -is-test -wait -current-config {5}:10003 -chain-length {6} -seed {7}'.format(clientHost.IP(), duration, lbound1, rbound1, ratio, serverHosts[0].IP(), numServers, getrandbits(61)))

    print(net.get('tester').cmd('_build/default/tester/tester_bin/tester.exe -mininet {0} {1} {2} -duration {3} {4}'.format(serverString, clientString, backupString, duration, failureString)))
#    CLI(net)

    net.stop()
