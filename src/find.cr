require "./find/cli"

module Find
  VERSION = "0.1.0"

  # TODO: Put your code here
end

rc = begin
  cli = Find::CLI.new
  cli.run
rescue e : ArgumentError
  STDERR.print "\e[31;1m" if STDERR.tty?
  STDERR.printf "[ERROR] %s: %s", Path[PROGRAM_NAME].basename, e.message
  STDERR.print "\e[0m" if STDERR.tty?
  STDERR << '\n'
  1
end

exit rc
