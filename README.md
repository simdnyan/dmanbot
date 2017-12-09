# [dmanbot](https://twitter.com/d_man_bot)

Twitter bot written in D Programming Language.

## Features

1. Search
2. Retweet
3. Follow

## Install

1. Edit config file
2. Create MySQL database and tables
3. Build & Run
4. Honor D-man

### 1. Edit config file

1. `cp dmanbot.yaml.example dmanbot.yaml`
2. Edit `dmanbot.yaml`

### 2. Create MySQL database and tables

1. `create database dmanbot;`
2. `create table dmanbot.retweets (id bigint not null, primary key (id));`
3. `create table dmanbot.follow_requests (id bigint not null, primary key (id));`
4. `create table dmanbot.words (word varchar(255) primary key unique not null, since_id bigint default 0 not null);`

### 3. Build & Run

1. `dub`

### 4. Honor D-man

![D-man](http://dlang.org/images/d3.png)

## License Information

MIT License

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
