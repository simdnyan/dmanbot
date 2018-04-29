module dmanbot;

import std.stdio,
       std.string,
       std.conv,
       std.json,
       std.datetime,
       std.typecons,
       std.variant,
       core.stdc.stdlib,
       requests,
       twitter4d,
       mysql,
       dyaml;

class DmanBot {

  const ulong MAX_TWEET_ID = ~0L;

  private Twitter4D  twitter;
  private Connection mysql;
  private bool       dry_run;
  private bool       do_not_post;
  private string[]   words;
  private string     banned;

  this (Node config, bool dry_run = false, bool do_not_post = false) {
    initialize(config, dry_run, do_not_post);
  }

  this (string file, bool dry_run = false, bool do_not_post = false) {
    Node config = Loader(file).load();
    initialize(config, dry_run, do_not_post);
  }

  void run(){
    foreach (string word; words) {
      ulong max_id = MAX_TWEET_ID;

      Prepared prepared = prepare(mysql, "select since_id from words where word=?;");
      prepared.setArgs(word);
      Nullable!Row words_row = prepared.queryRow();
      ulong since_id = words_row.isNull ? 0 : words_row[0].get!long;

      JSONValue[] statuses = [];
      while (true) {
        auto status = search(word, max_id, since_id);
        if (status.length == 0) break;
        statuses ~= status;
        max_id = status[$ - 1]["id"].integer - 1;
        if (max_id <= since_id) break;
      }

      foreach_reverse (status; statuses) {
        ulong tweet_id  = status["id"].integer;
        auto tweet_text = status["text"].str;
        auto user       = status["user"];

        if (retweet(tweet_id)) {
          writefln("retweet: %d, %s, %s, %s", tweet_id, string_to_datetime(status["created_at"].str), user["screen_name"], tweet_text);

          if (!dry_run && tweet_id > since_id) {
            Prepared insert = prepare(mysql, "insert into words (since_id, word) values (?, ?) on duplicate key update since_id = ?;");
            insert.setArgs(tweet_id, word, tweet_id);
            insert.exec();
            since_id = tweet_id;
          }
        }
        if (follow(user["id"].integer)) {
          writefln("follow: %s, @%s", user["name"].str, user["screen_name"].str);
        }
      }
    }
  }

  JSONValue[] search(string q, ulong max_id, ulong since_id) {
    auto request = [
           "q":           format("\"%s\"", q.replace(" ", "\" \"")) ~ banned,
           "count":       "100",
           "result_type": "recent",
           "since_id":    since_id.to!string,
           "max_id":      max_id.to!string
         ];

    if (dry_run) writefln("search: %s", request);

    Response ret;
    try {
      ret = twitter.request("GET", "search/tweets.json", request);
      if (ret.code != 200) {
        throw new Exception(ret.responseBody.to!string);
      }
    } catch (Exception e) {
      stderr.writefln("[%s] Catch %s. Can't get tweets. { \"q\": \"%s\", \"max_id\": \"%d\" }", currentTime(), e.msg, q, max_id);
      exit(1);
      assert(0);
    }
    return parseJSON(ret.responseBody.to!string)["statuses"].array;
  }

  bool retweet(ulong tweet_id) {
    Prepared prepared = prepare(mysql, "select * from retweets where id=?;");
    prepared.setArgs(tweet_id);
    if (!prepared.queryRow().isNull) return false;
    if (!dry_run) {
      try {
        if (!do_not_post) {
          Response ret;
          ret = twitter.request("POST", format("statuses/retweet/%d.json", tweet_id));
          if (ret.code != 200)
            throw new Exception(ret.responseBody.to!string);
        }
        Prepared insert = prepare(mysql, "insert into retweets (id) values (?);");
        insert.setArgs(tweet_id);
        insert.exec();
      } catch (Exception e) {
        stderr.writefln("[%s] Catch %s. Can't retweet. { \"tweet_id\": \"%d\"}", currentTime(), e.msg, tweet_id);
        return false;
      }
    }
    return true;
  }

  bool follow(ulong user_id) {
    Prepared prepared = prepare(mysql, "select * from follow_requests where id=?;");
    prepared.setArgs(user_id);
    if (!prepared.queryRow().isNull) return false;
    if (!dry_run) {
      try {
        if (!do_not_post) {
          Response ret;
          ret = twitter.request("POST", "friendships/create.json", ["user_id": user_id.to!string]);
          if (ret.code != 200)
            throw new Exception(ret.responseBody.to!string);
        }
        Prepared insert = prepare(mysql, "insert into follow_requests (id) values (?);");
        insert.setArgs(user_id);
        insert.exec();
      } catch (Exception e) {
        stderr.writefln("[%s] Catch %s. Can't send a follow request. { \"user_id\": { \"%d\" }}", currentTime(), e.msg, user_id);
        return false;
      }
    }
    return true;
  }

  private string currentTime(){
    auto time = Clock.currTime();
    return format(
                   "%04d-%02d-%02d %02d:%02d:%02d",
                   time.year,
                   time.month,
                   time.day,
                   time.hour,
                   time.minute,
                   time.second
                 );
  }

  private DateTime string_to_datetime(string str, int timezone = 9){
    auto arr = str.split;
    auto datetime = DateTime.fromSimpleString(arr[5] ~ "-" ~ arr[1] ~ "-" ~ arr[2] ~ " " ~ arr[3]);
    return datetime.roll!"hours"(timezone);
  }

  private void initialize(Node config, bool dry_run = false, bool do_not_post = false) {
    initTwitter(config["twitter"]);
    initMySQL(config["mysql"]);
    foreach(string word; config["words"]) {
      words ~= word;
    }
    if ("banned" in config)
      foreach(string word; config["banned"]) {
        banned ~= " -" ~ word;
      }
    this.dry_run = dry_run;
    this.do_not_post = do_not_post;
  }

  private void initMySQL(Node config) {
    mysql = new Connection(
      config["host"].as!string,
      config["user"].as!string,
      config["password"].as!string,
      config["database"].as!string,
      config["port"].as!ushort
    );
  }

  private void initTwitter(Node config) {
    twitter = new Twitter4D([
      "consumerKey"      : config["consumerKey"].as!string,
      "consumerSecret"   : config["consumerSecret"].as!string,
      "accessToken"      : config["accessToken"].as!string,
      "accessTokenSecret": config["accessTokenSecret"].as!string
    ]);
  }

}
