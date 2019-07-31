# RVM Container for INKI

## Good To Know
- rvm is only available if login shell is used i.e. use `bash -l`.
    - docker run -it inki_repo_inki bash -l
    - docker exec -it <CONTAINER_ID> bash -l
    - function dsshl() {
        # TODO: autocompletion for docker containers available to ssh into.
        docker exec -it $1 bash -l
      }

## TODOs

[ ] install in Dockerfile? // debconf: delaying package configuration, since apt-utils is not installed 
[ ] YAML safe loading is not available. Please upgrade psych to a version that supports safe loading (>= 2.0).
[ ] unable to convert U+00E9 from UTF-8 to US-ASCII for spec/bundler/bundler_spec.rb, skipping
[ ] set locale?
[ ] tzdata (Time Zone Data) is not set correctly (-2h from vienna)

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
    * look at inki documentation/requirements

## solution
`
 amingilani commented Aug 12, 2017

Ahhh, adding the tzinfo-data gem didn't work for me but installing tzdata via apt did! Thanks @rowland!

I think this could be classified as a bug for this project since it's geared towards Rails but can't support rails out of the box.
`

# Inki Rails Notes

## Commands
Create new model example with column data of type string (VARCHAR?)
$ rails generate model example data:string 

Migrate newly create migration files (e.g. the example model)
$ RAILS_ENV=production rake db:migrate


# Inki Database Specifics

# First occurence of `prefix`
`
create_table "prices", force: :cascade do |t| 
   t.integer  "pricelist_reference_id"
   t.string   "description",             limit: 255 
   t.string   "prefix",                  limit: 255 
   t.float    "sales_price_in_peak"
   t.float    "sales_price_off_peak"
   t.float    "purchase_price_in_peak"
   t.float    "purchase_price_off_peak"
   t.integer  "reference_id"
   t.datetime "expired_at"
   t.string   "problems",                limit: 255 
   t.integer  "owner_reference_id"
   t.datetime "expected_expiry"
   t.datetime "created_at"
   t.datetime "updated_at"
end 
`

## convert this to rails command
`
$ rails generate model prices \
                     pricelist_reference_id:integer \
                     description:string \
                     prefix:string \
                     sales_price_in_peak:float \
                     sales_price_off_peak:float \
                     purchase_price_in_peak:float \
                     purchase_price_off_peak:float \
                     reference_id:integer \
                     expired_at:datetime \
                     problems:string \
                     owner_reference_id:integer \
                     expected_expiry:datetime
                     created_at:datetime \
                     updated_at:datetime

`

# Second  occurence ocreated_at"                          f `prefix`
create_table "voip_prupdated_at"                          ices", force: :cascade do |t|
    t.integer  "voip_pricelist_id"
    t.string   "description",             limit: 255
    t.string   "prefix",                  limit: 255
    t.float    "sales_price_in_peak"
    t.float    "sales_price_off_peak"
    t.float    "purchase_price_in_peak"
    t.float    "purchase_price_off_peak"
    t.string   "problems",                limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
end

