import std.stdio,
       std.string,
       std.json,
       std.getopt,
       dmanbot;

const ulong MAX_TWEET_ID = ~0L;

string config_file = "dmanbot.yaml";
bool   dryrun      = false;

void main(string[] args) {

  getopt(args,
    "config",  &config_file,
    "dry-run", &dryrun
  );

  auto dmanbot = new DmanBot(config_file, dryrun);

  foreach (string word; dmanbot.words) {
    ulong max_id = MAX_TWEET_ID;

    while (true) {

      auto statuses = dmanbot.search(word, max_id);
      if (statuses.length == 0) break;

      foreach (status; statuses) {
        ulong tweet_id  = status["id"].integer;
        auto tweet_text = status["text"].str;
        auto user       = status["user"];

        max_id = tweet_id - 1;

        if (!(tweet_text[0..4] == "RT @")) {
          if (dmanbot.retweet(tweet_id)) {
            writefln("retweet: %d, %s, %s, %s", tweet_id, status["created_at"], user["screen_name"], tweet_text);
          }
          if (dmanbot.follow(user["id"].integer)) {
            writefln("follow:  %s, @%s", user["name"].str, user["screen_name"].str);
          }
        }
      }
    }
  }
}

