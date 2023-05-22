require "./expression"

class Find::CLI
  property args : Array(String)
  property dirs : Array(Path)
  property expression : String

  def initialize(@args = ARGV.dup)
    @dirs = [] of Path
    expr : String? = nil
    opts = @args.dup
    while opt = opts.shift?
      case opt
      when "--expression", "-e"
        expr = opts.shift? || raise ArgumentError.new "#{opt}: requires an argument"
      when "--"
        @dirs += opts.map { |o| Path[o] }
        opts = [] of String
      when %r{^-}
        raise ArgumentError.new "#{opt}: unknown option"
      else
        @dirs << Path[opt]
      end
    end
    raise ArgumentError.new "must give an expression with --expression or -e" unless expr
    @expression = expr
  end

  def run
    puts "#{@dirs.size} directories"
    @dirs.each_with_index do |dir, idx|
      printf "%4d %s", 1 + idx, dir
      if !File.exists?(dir)
        print " (missing)"
      elsif !File.directory?(dir)
        print " (not a directory)"
      end
      print "\n"
    end
    if expr = Find::Expression::Parser.new(@expression).parse
      puts expr
      0
    else
      puts "FAILED TO PARSE"
      1
    end
  end
end
