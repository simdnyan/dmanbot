import std.stdio,
       std.getopt,
       dmanbot;

string config_file = "dmanbot.yaml";
bool   dryrun      = false;

void main(string[] args) {
  getopt(args,
    "config",  &config_file,
    "dry-run", &dryrun
  );

  auto dmanbot = new DmanBot(config_file, dryrun);
  dmanbot.run;
}

