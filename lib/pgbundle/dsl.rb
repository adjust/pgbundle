module PgBundle
  # The Dsl class defines the Domain Specific Language for the PgFile
  # it's mainly user to parse a PgFile and return a Definition Object
  class Dsl
    def initialize
      @definition = Definition.new
      @extensions = []
    end

    def eval_pgfile(pgfile)
      contents ||= File.read(pgfile.to_s)
      instance_eval(contents)
      @definition
    rescue SyntaxError => e
      syntax_msg = e.message.gsub("#{pgfile}:", 'on line ')
      raise PgfileError, "Pgfile syntax error #{syntax_msg}"
    rescue ScriptError, RegexpError, NameError, ArgumentError => e
      e.backtrace[0] = "#{e.backtrace[0]}: #{e.message} (#{e.class})"
      puts e.backtrace.join("\n       ")
      raise PgfileError, "There was an error in your Pgfile," \
        " and PgBundle cannot continue. " \
        + e.message
    end

    def database(*args)
      opts = extract_options!(args)
      @definition.database = Database.new(args.first, opts)
    end

    def pgx(*args)
      opts = extract_options!(args)
      ext = Extension.new(*args, opts)
      @definition.extensions[ext.name] = ext
    end

    def extract_options!(arr)
      if arr.last.is_a? Hash
        arr.pop
      else
        {}
      end
    end
  end
end
