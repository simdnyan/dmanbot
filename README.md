# dmanbot

Twitter bot written in D Programming Language.

## Features

1. Search
2. Retweet
3. Follow

## Install

1. Edit config File
2. Create MySQL database and tables
3. Build & Run

### Edit config file

1. `cp dmanbot.yaml.example dmanbot.yaml`
2. Edit twitter API and mysql settings

### Create MySQL database and tables

1. `create database dmanbot;`
2. `create table dmabot.retweets (id bigint not null, primary key (id));`
3. `create table dmanbot.follow_requests (id bigint not null, primary key (id));`

### Build & Run

1. `dub`

## License Information

MIT License

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
