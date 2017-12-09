import std.stdio,
       std.getopt,
       dmanbot;

string config_file = "dmanbot.yaml";
bool   dryrun      = false;
bool   do_not_post = false;

void main(string[] args) {
  getopt(args,
    "config",      &config_file,
    "dry-run",     &dryrun,
    "do-not-post", &do_not_post
  );

  auto dmanbot = new DmanBot(config_file, dryrun, do_not_post);
  dmanbot.run;
}

