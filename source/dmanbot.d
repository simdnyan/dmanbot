module dmanbot;

import std.stdio,
       std.string,
       std.conv,
       std.json,
       std.datetime,
       twitter4d,
       mysql.d,
       dyaml.all;

class DmanBot {

  private Twitter4D twitter;
  private Mysql     mysql;
  private bool      dryrun = false;
  string[] words;

  this (Node config, bool flag = false) {
    initialize(config, flag);
  }

  this (string file, bool flag = false) {
    Node config = Loader(file).load();
    initialize(config, flag);
  }

  JSONValue[] search(string q, ulong max_id) {
    auto request = [
           "q":           q,
           "count":       "100",
           "result_type": "recent",
           "max_id":      max_id.to!string
         ];

    if (dryrun) writefln("search:  %s", request);

    try {
      auto ret = twitter.request("GET", "search/tweets.json", request);
      return parseJSON(ret)["statuses"].array;
    } catch (Exception e) {
      stderr.writefln("[%s] Catch %s. Can't get tweets. { \"q\": \"%s\", \"max_id\": \"%d\" }", currentTime(), e.msg, q, max_id);
      return [];
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

  private void initialize(Node config, bool flag) {
    initTwitter(config["twitter"]);
    initMySQL(config["mysql"]);
    foreach(string word; config["words"]) {
      words ~= format("\"%s\"", word.replace(" ", "\" \""));
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
