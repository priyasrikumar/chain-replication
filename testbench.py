#!/usr/bin/env python

import test 

import csv
import glob
import os

if __name__ == '__main__':
    results = open('test.csv', 'w')
    writer = csv.writer(results)
    writer.writerow(['chain length', 'ratio', 'failures', 'query throughput', 'update throughput', 'total throughput'])
    results.flush()
    configs = glob.glob('./configs/test*.config')
    for configName in configs:
        config = open('{0}'.format(configName), 'r')
        configLines = config.readlines()
        configLines = [line.strip() for line in configLines]
        numServers = int((configLines[0])[configLines[0].index('=')+1:])
        duration = int((configLines[3])[configLines[3].index('=')+1:])
        ratio = float((configLines[4])[configLines[4].index('=')+1:])
        failures = ((configLines[7])[configLines[7].index('=')+1:]).split()
        updateThroughput = [0] * duration
        queryThroughput = [0] * duration
        os.system('sudo rm *.out')
        os.system('sudo python3 test2.py {0}'.format(configName))
        os.system('sudo mn -c')
        outFiles = glob.glob('./*.out')
        for outFile in outFiles: 
            out = open('{0}'.format(outFile), 'r')
            lines = out.readlines()
            lines = [line.strip() for line in lines]
            for i, elem in enumerate((lines[1].split(':'))[1:]):
                updateThroughput[i] += int(elem)
            for i, elem in enumerate((lines[2].split(':'))[1:]):
                queryThroughput[i] += int(elem) 
        totalThroughput = [0] * duration
        for i, elem in enumerate(zip(updateThroughput, queryThroughput)):
            totalThroughput[i] = elem[0] + elem[1]
        writer.writerow(['{0}'.format(numServers), '{0}'.format(ratio), '{0}'.format(failures), '{0}'.format(updateThroughput), '{0}'.format(queryThroughput), '{0}'.format(totalThroughput)])
        results.flush()

