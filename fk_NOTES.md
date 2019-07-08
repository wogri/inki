# RVM Container for INKI

## Good To Know
- rvm is only available if login shell is used i.e. use `bash -l`.
    - docker run -it inki_repo_inki bash -l
    - docker exec -it <CONTAINER_ID> bash -l

## TODOs

[ ] install in Dockerfile? // debconf: delaying package configuration, since apt-utils is not installed 

PATH==/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

- /usr/local/sbin
- /usr/local/bin
- /usr/sbin
- /usr/bin
- /sbin
- /bin


## Issues:
* compilation error: libpq-fe.h
    * dump:
    `"gcc -E -I/usr/local/rvm/rubies/ruby-1.9.3-p551/include/ruby-1.9.1/x86_64-linux -I/usr/local/rvm/rubies/ruby-1.9.3-p551/include/ruby-1.9.1/ruby/backward -I/usr/local/rvm/rubies/ruby-1.9.3-p551/include/ruby-1.9.1 -I.     -O3 -ggdb -Wall -Wextra -Wno-unused-parameter -Wno-parentheses -Wno-long-long -Wno-missing-field-initializers -Wpointer-arith -Wwrite-strings -Wdeclaration-after-statement -Wimplicit-function-declaration  -fPIC  conftest.c -o conftest.i"
conftest.c:3:10: fatal error: libpq-fe.h: No such file or directory
 #include <libpq-fe.h>
          ^~~~~~~~~~~~
compilation terminated.`
    * sol?: sudo apt-get install libpq-dev
