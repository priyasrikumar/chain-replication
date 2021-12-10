#!/usr/bin/env python

import test 

import csv
import glob
import os

if __name__ == '__main__':
    results = open('results.csv', 'w')
    writer = csv.writer(results)
    writer.writerow(['chain length', 'ratio', 'throughput'])
    configs = glob.glob('./*.config')
    for configName in configs:
        config = open('{0}'.format(configName), 'r')
        configLines = config.readlines()
        configLines = [line.strip() for line in configLines]
        numServers = int((configLines[0])[configLines[0].index('=')+1:])
        duration = int((configLines[3])[configLines[3].index('=')+1:])
        ratio = float((configLines[4])[configLines[4].index('=')+1:])
        throughputTmp = 0
        os.system('sudo rm *.out')
        os.system('sudo python3 test.py {0}'.format(configName))
        os.system('sudo mn -c')
        outFiles = glob.glob('./*.out')
        for outFile in outFiles: 
            out = open('{0}'.format(outFile), 'r')
            lines = out.readlines()
            lines = [line.strip() for line in lines]
            throughputTmp += int(lines[1])
        throughput = throughputTmp / duration
        writer.writerow(['{0}'.format(numServers), '{0}'.format(ratio), '{0}'.format(throughput)])
        results.flush()

