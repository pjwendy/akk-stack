#!/usr/bin/perl

#########################################
# load config
#########################################
use JSON;
my $json = new JSON();

my $content;
my $config_file = "/home/eqemu/server/eqemu_config.json";

# Check if config file exists
if (!-e $config_file) {
    die "[create-symlinks] config file [$config_file] does not exist";
}

open(my $fh, '<', $config_file) or die "[create-symlinks] cannot open config file [$config_file]: $!";
{
    local $/;
    $content = <$fh>;
}
close($fh);

# Check if content is empty
if (!$content || length($content) == 0) {
    die "[create-symlinks] config file [$config_file] is empty";
}

# Try to decode JSON with better error handling
my $config;
eval {
    $config = $json->decode($content);
};
if ($@) {
    print "[create-symlinks] ERROR: Failed to parse JSON from [$config_file]\n";
    print "[create-symlinks] JSON error: $@\n";
    print "[create-symlinks] File content (first 500 chars): " . substr($content, 0, 500) . "\n";
    die "[create-symlinks] Cannot continue with malformed JSON config";
}

#########################################
# paths
#########################################
my $code_path                = "/home/eqemu/code/";
my $patches_source_path      = $code_path . "utils/patches";
my $binary_path              = "/home/eqemu/code/build/bin";
my $server_path              = "/home/eqemu/server";
my $patches_server_directory = $server_path . "/" . $config->{"server"}{"directories"}{"patches"};
my $opcodes_server_directory = $server_path . "/" . $config->{"server"}{"directories"}{"opcodes"};

#########################################
# server binaries
#########################################
my @binaries = (
    "eqlaunch",
    "export_client_files",
    "import_client_files",
    "loginserver",
    "queryserv",
    "shared_memory",
    "ucs",
    "world",
    "zone",
);

foreach my $bin (@binaries) {
    my $source = $binary_path . "/" . $bin;
    my $target = $server_path . "/bin/" . $bin;
    print "\tSymlinking Source: " . $source . " Target: " . $target . "\n";
    print `ln -s -f $source $target`
}

#########################################
# patches
#########################################
print "# Symlinking patches\n";

opendir(DH, $patches_source_path);
my @files = readdir(DH);

foreach my $file (@files) {
    my $source = $patches_source_path . "/" . $file;
    my $target = $patches_server_directory . $file;
    next if (substr($file, 0, 1) eq ".");
    next if (substr($file, 0, 2) eq "..");
    next if $file !~ /patch/i;
    print "\tSymlinking Source: " . $source . " Target: " . $target . "\n";
    print `ln -s -f $source $target`
}

#########################################
# opcodes
#########################################
print "# Symlinking opcodes\n";

opendir(DH, $patches_source_path);
@files = readdir(DH);

foreach my $file (@files) {
    my $source = $patches_source_path . "/" . $file;
    my $target = $opcodes_server_directory . $file;
    next if (substr($file, 0, 1) eq ".");
    next if (substr($file, 0, 2) eq "..");
    next if $file !~ /opcodes/i;
    print "\tSymlinking Source: " . $source . " Target: " . $target . "\n";
    print `ln -s -f $source $target`
}

#########################################
# plugins
#########################################
print "# Symlinking plugins\n";
print "\tSymlinking Source: $server_path/quests/plugins/ Target: $server_path\n";
print `rm $server_path/plugins; ln -s $server_path/quests/plugins/ $server_path`;

#########################################
# lua_modules
#########################################
print "# Symlinking lua_modules\n";
print "\tSymlinking Source: $server_path/quests/lua_modules/ Target: $server_path\n";
print `rm $server_path/lua_modules; ln -s $server_path/quests/lua_modules/ $server_path`;
