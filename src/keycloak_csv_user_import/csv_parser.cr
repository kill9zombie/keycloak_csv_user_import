require "csv"

module KeycloakCsvUserImport
  class CSVParserErrors < Exception
    getter errors

    def initialize(message, @errors = [] of String)
      super(message)
    end
  end

  class CSVParser

    @valid_groups : Array(String)

    EXPECTED_HEADERS = ["username", "first name", "last name", "email", "group", "gender", "birth_day", "birth_month", "birth_year"]

    def initialize(@log = Logger.new("/dev/null"), @working_dir = "./", @valid_groups = ["be313ae0-a99a-4479-bfb4-6d24f913d8ee", "School Admins", "Teachers", "Students"])
    end

    def validate_header_line(input)
      current_headers = CSV.each_row(input).first.map {|x| x.downcase.strip}
      if current_headers == EXPECTED_HEADERS
        {:ok, "Header line OK"}
      else
        {:error, "Invalid header line found on the CSV file, expected: \"#{EXPECTED_HEADERS}\", but got: \"#{current_headers}\""}
      end
    end

    def validate_groups(input)
      index = 1
      results = [] of {Symbol, String}
      csv = CSV.new(input, headers: true)
      csv.each do |row|
        group = row["group"].strip
        if @valid_groups.includes?(group)
          results << {:ok, "Group #{group} on line #{index} OK"}
        else
          results << {:error, "Invalid group \"#{group}\" on line #{index}, should be one of: #{@valid_groups}"}
        end
        index += 1
      end
      results
    end

    def validate_birth_day(input)
      index = 1
      results = [] of {Symbol, String}
      csv = CSV.new(input, headers: true)
      csv.each do |row|
        begin
          day = row["birth_day"].to_i
          if day > 0 && day < 32
            results << {:ok, "Day #{day} OK"}
          else
            results << {:error, "Bad birth_day found on line #{index}, expected a number between 1 and 31, but got: #{day}"}
          end
        rescue ArgumentError
          results << {:error, "Bad birth_day found on line #{index}, expected a number between 1 and 31, but found: #{row["birth_day"]}"}

        end
        index += 1
      end
      results
    end

    def validate_birth_month(input)
      index = 1
      results = [] of {Symbol, String}
      csv = CSV.new(input, headers: true)
      csv.each do |row|
        begin
          month = row["birth_month"].to_i
          if month > 0 && month < 13
            results << {:ok, "Month #{month} OK"}
          else
            results << {:error, "Bad birth_month found on line #{index}, expected a number between 1 and 12, but got: #{month}"}
          end
        rescue ArgumentError
          results << {:error, "Bad birth_month found on line #{index}, expected a number between 1 and 12, but found: #{row["birth_month"]}"}

        end
        index += 1
      end
      results
    end

    def validate_birth_year(input)
      index = 1
      results = [] of {Symbol, String}
      csv = CSV.new(input, headers: true)
      csv.each do |row|
        begin
          year = row["birth_year"].to_i
          results << {:ok, "Year #{year} OK"}
        rescue ArgumentError
          results << {:error, "Bad birth_year found on line #{index}, expected a number but found: #{row["birth_year"]}"}

        end
        index += 1
      end
      results
    end

    def validate_birth_date(input)
      index = 1
      results = [] of {Symbol, String}
      csv = CSV.new(input, headers: true)
      csv.each do |row|
        begin
          time = Time.utc(row["birth_year"].to_i, row["birth_month"].to_i, row["birth_day"].to_i)
          results << {:ok, "Birth date parsed as #{time}"}
        rescue ArgumentError
          results << {:error, "Couldn't parse the birth_day, birth_month, birth_year into a valid date on line #{index}"}

        end
        index += 1
      end
      results
    end

    # Call all the validators.
    #
    # If everything's ok we return `:ok`, if not we'll return
    # a tuple starting with `:error` and a list of errors.
    #
    #    {:ok, "Thing was OK"}
    #
    #    {:error, "Error happened, here's how to fix it"}
    #
    #   [{:ok, "OK"}, {:error, "Thing X"}]
    #
    def validate(input : String)
      validators = [
        ->(x : String) { validate_header_line(x) },
        ->(x : String) { validate_groups(x) },
        ->(x : String) { validate_birth_day(x) },
        ->(x : String) { validate_birth_month(x) },
        ->(x : String) { validate_birth_year(x) },
        ->(x : String) { validate_birth_date(x) }
      ]

      validators.map do |validator|
        validator.call(input)
      end.flatten
    end

    def load_file(filename)
      if File.readable?(filename)
        begin
          input = File.read(filename)

          csv = CSV.new(input, headers: true)
          csv.each {|x| }
          input
        rescue e : CSV::MalformedCSVError
          CSVParserErrors.new("Bad input file: #{e.message}")
        end
      else
        # TODO - improve the error message, could we do a "did you mean?" ?
        CSVParserErrors.new("Could not read file: #{filename}, please check the spelling and path.")
      end
    end

    def parse_users(input)
      # Should we pin the order of the headers and
      # use something like CSV.each_row.map ... ?
      csv = CSV.new(input, headers: true)
      users = [] of User
      csv.each do |row|

        attributes = {"gender" => row["gender"].strip,
                      "birthday" => Time.utc(
                          row["birth_year"].to_i,
                          row["birth_month"].to_i,
                          row["birth_day"].to_i
                        ).to_rfc3339
                     }

        user = User.new(row["username"].strip,
                        row["first name"].strip,
                        row["last name"].strip,
                        row["email"].strip,
                        [row["group"].strip],
                        attributes)
                        # row["gender"].strip,
                        # row["birth_day"].strip,
                        # row["birth_month"].strip,
                        # row["birth_year"].strip)

        @log.debug "Parsed user: #{user.username}"

        users << user
      end
      users

    end

    def parse(filename)
      prefix = "#{self.class}#parse :: "
      @log.debug "#{prefix} Parsing filename: #{filename}"
      string_or_error = load_file(filename)

      case string_or_error
      when String
        @log.debug "#{prefix} CSV file loaded OK"
        results = validate(string_or_error)
        @log.debug "#{prefix} Validation results: #{results}"

        if results.all? {|x| x.first == :ok }
          parse_users(string_or_error)
        else
          errors = results
                    .select {|x| x[0] == :error}
                    .map {|x| x[1]}

          raise CSVParserErrors.new("Error(s) detected while parsing the CSV input file", errors)
        end

      when CSVParserErrors
        raise string_or_error
      end
    end
  end
end
