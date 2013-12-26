M7 Distributed Testing Platform

This is a broad overview of the structure of M7 as well as how to use the platform
to perform both automated web and network testing. Note that if you want to publish
this directory to a web site, and access the result XML files from your browser, you
will need to configure Apache by hand.

RECOMMENDATIONS
  
  M7 is a testing framework designed to be installed on multiple servers independent
  of geographical location. Currently this software has the following requirements:

  Operating System
  - CentOS 6.x or CentOS 5.x

  Applications
  - mtr (version 0.84 recommended)
  - bc (perform results calculations)
  - xmllint (parse the test plan files)
  - perl

  Network
    It is recommended to set the local server's hostname to something besides 
    'localhost.localdomain'. Nodes are typically identified using the value returned by
    'hostname -s'.
    
    All servers should be accessible either by a public IP address, or port forwarding
    to allow SSH access.

OVERVIEW

  Installation Location
    M7 is installed in the home directory of any system user account. All paths in the
    platform are relative to the home directory. Note that some additional permissions
    and configuration will be required for the user account.

  Cluster Layout
    M7 has the following structure, consisting of a primary director node and an arbitrary
    number of worker nodes.
  
      [Director Node]-------> [Worker Node 1]
                     |------> [Worker Node 2]
                     |------> [Worker Node 3]
                     |------> [Worker Node 4]
                 
    Nodes and their properties are tracked in a SQLite database found in the '~/db/cluster.db'
    file. When adding new nodes you will have to manually update this database and send
    the new copy to your cluster nodes. Also note that the director node doubles as a worker
    node.
    
  Remote Access
    M7 cluster nodes share a set of SSH keys that allow for automated transfer of files and
    execution of commands. These keys are stored in the '~/.ssh' directory and should use the
    following naming convention:
    
      Private Key: ~/.ssh/m7.key
      Public Key:  ~/.ssh/m7.key.pub
      
    You are free to use a different naming convention, but you will have to modify the platform
    scripts to account for this.
    
RUNNING TESTS

  The first step to running any tests is to define a test plan XML file. Currently there are two
  types of supported tests. Please see the following URLs for examples of both web and network
  test plan XML files (read the comments for details on how to build your own test plan):
  
    Web Test Example: 	  /examples/web-test-plan.xml
    Network Test Example: /examples/net-test-plan.xml
  
  WEB TESTS
    Web tests typically are configured to have a target web site and different types of test
    definitions depending on your testing scenario. Currently there are two supported test 
    types for web tests:
    
    Test Threads
      To simulate simultaneous user connections, you can specify a number of threads to run
      side-by-side for every test definition.
    
    Single File Download
      You can specify a single file to download, as well as the number of times (samples) to
      download the file. The sample statistics will be averaged.
      
    Multiple File Download
      You can specify a list of file paths to download, as well as the number of samples. The
      files will be downloaded in order, and the statistics of each transfer will be averaged
      out for that particular sample.
      
    [Director]--<--(single,multi-file download)--<--/------\
    [Worker 1]--<--(single,multi-file download)--<--| Host |
    [Worker 2]--<--(single,multi-file download)--<--\------/
      
  NETWORK TESTS
    Network tests by defaults run between every node in the cluster. For example, if you have
    three nodes configured (1 director, 2 worker). The test will look something like this:
    
    [Director]----(ping,mtr,traceroute)---->[Worker 1]
              |---(ping,mtr,traceroute)---->[Worker 2]
              
    [Worker 1]----(ping,mtr,traceroute)---->[Director]
              |---(ping,mtr,traceroute)---->[Worker 2]
              
    [Worker 2]----(ping,mtr,traceroute)---->[Director]
              |---(ping,mtr,traceroute)---->[Worker 1]
              
    Additional Nodes
      You can also specify a list of satellite hosts to run the same tests on. Each node in the
      testing cluster will run either mtr, traceroute, or ping to the satellite node.
      
      [Director]-----(ping,mtr,traceroute)-----/------\
      [Worker 1]-----(ping,mtr,traceroute)-----| Host |
      [Worker 2]-----(ping,mtr,traceroute)-----\------/
      
  LAUNCH A TEST PLAN
    To run a test plan, you must copy the XML file to the director node as the M7 user account
    that owns the installed software:
    
    scp test-plan.xml m7@some.host.com:~/plans/.
    
    Once the test has been copied over, you can run the test as the M7 user account from the
    director node:
    
    m7 run ~/plans/test-plan.xml