# gen_was_dumps.py
import sys
# Read arguments passed from the shell script
nodeName = sys.argv[0]
serverName = sys.argv[1]
# Query the JVM MBean
objectName = AdminControl.queryNames('WebSphere:type=JVM,process=' + serverName + ',node=' + nodeName + ',*')
# Generate Heap Dump
heapDumpResult = AdminControl.invoke(objectName, 'generateHeapDump')
#print('Heap Dump Result:', heapDumpResult)
# Generate Java Core
javaCoreResult = AdminControl.invoke(objectName, 'dumpThreads')
#print('Java Core Result:', javaCoreResult)