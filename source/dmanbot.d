module dmanbot;

import std.stdio,
       std.string,
       std.conv,
       std.json,
       std.datetime,
       core.stdc.stdlib,
       twitter4d,
       mysql.d,
       dyaml.all;

class DmanBot {

  const ulong MAX_TWEET_ID = ~0L;

  private Twitter4D twitter;
  private Mysql     mysql;
  private bool      dryrun;
  private string[]  words;

  this (Node config, bool flag = false) {
    initialize(config, flag);
  }

  this (string file, bool flag = false) {
    Node config = Loader(file).load();
    initialize(config, flag);
  }

  void run(){
    foreach (string word; words) {
      ulong max_id = MAX_TWEET_ID;

      auto words_rows = mysql.query("select * from words where word=?;", word);
      ulong since_id = 0;
      foreach (row; words_rows) {
        since_id = row["since_id"].to!ulong;
      }

      JSONValue[] statuses = [];
      while (true) {
        auto status = search(word, max_id, since_id);
        if (status.length == 0) break;
        statuses ~= status;
        max_id = status[$ - 1]["id"].integer - 1;
        if (max_id <= since_id) break;
      }

      foreach_reverse (status; statuses) {
        if ("retweeted_status" in status.object) continue;
        ulong tweet_id  = status["id"].integer;
        auto tweet_text = status["text"].str;
        auto user       = status["user"];

        if (retweet(tweet_id)) {
          writefln("retweet: %d, %s, %s, %s", tweet_id, string_to_datetime(status["created_at"].str), user["screen_name"], tweet_text);

          if (!dryrun && tweet_id > since_id) {
            auto rows = mysql.query("select * from words where word=?;", word);
            if (rows.length > 0) {
              mysql.query("update words set since_id=? where word=?;", tweet_id, word);
            } else {
              mysql.query("insert into words (since_id, word) values (?, ?);", tweet_id, word);
            }
            since_id = tweet_id;
          }
        }
        if (follow(user["id"].integer)) {
          writefln("follow:  %s, @%s", user["name"].str, user["screen_name"].str);
        }
      }
    }
  }

  JSONValue[] search(string q, ulong max_id, ulong since_id) {
    auto request = [
           "q":           format("\"%s\"", q.replace(" ", "\" \"")),
           "count":       "100",
           "result_type": "recent",
           "since_id":    since_id.to!string,
           "max_id":      max_id.to!string
         ];

    if (dryrun) writefln("search:  %s", request);

    try {
      auto ret = twitter.request("GET", "search/tweets.json", request);
      return parseJSON(ret)["statuses"].array;
    } catch (Exception e) {
      stderr.writefln("[%s] Catch %s. Can't get tweets. { \"q\": \"%s\", \"max_id\": \"%d\" }", currentTime(), e.msg, q, max_id);
      exit(1);
      assert(0);
    }
  }

  bool retweet(ulong tweet_id) {
    auto rows = mysql.query("select * from retweets where id=?;", tweet_id);
    if (rows.length > 0) return false;
    if (!dryrun) {
      try {
        twitter.request("POST", format("statuses/retweet/%d.json", tweet_id));
        mysql.query("insert into retweets (id) values (?);", tweet_id);
      } catch (Exception e) {
        stderr.writefln("[%s] Catch %s. Can't retweet. { \"tweet_id\": \"%d\"}", currentTime(), e.msg, tweet_id);
        return false;
      }
    }
    return true;
  }

  bool follow(ulong user_id) {
    auto rows = mysql.query("select * from follow_requests where id=?;", user_id);
    if (rows.length > 0) return false;
    if (!dryrun) {
      try {
        twitter.request("POST", "friendships/create.json", ["user_id": user_id.to!string]);
        mysql.query("insert into follow_requests (id) values (?);", user_id);
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

  private void initialize(Node config, bool flag = false) {
    initTwitter(config["twitter"]);
    initMySQL(config["mysql"]);
    foreach(string word; config["words"]) {
      words ~= word;
    }
    dryrun = flag;
  }

  private void initMySQL(Node config) {
    mysql = new Mysql(
      config["host"].as!string,
      config["port"].as!uint,
      config["user"].as!string,
      config["password"].as!string,
      config["database"].as!string
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
