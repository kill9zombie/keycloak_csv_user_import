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

    VALID_GENDERS = ["M", "F", "O"]
    VALID_HEADERS = ["first name", "last name", "email", "group", "gender", "birth_year"]

    def initialize(valid_group_representations, @log = Logger.new(nil))
      @usernames_count = {} of Tuple(String, String) => UInt32

      @valid_groups = valid_group_representations.map {|x| x[:name]}
    end

    def validate_header_line(input)
      current_headers = CSV.each_row(input).first.map {|x| x.downcase.strip}
      if current_headers == VALID_HEADERS
        {:ok, "Header line OK"}
      else
        {:error, "Invalid header line found on the CSV file, expected: \"#{VALID_HEADERS}\", but got: \"#{current_headers}\""}
      end
    end

    def validate_groups(input)
      index = 1
      results = [] of {Symbol, String}
      csv = CSV.new(input, headers: true)
      csv.each do |row|
        group = row["group"].strip
        if @valid_groups.includes?(group)
          results << {:ok, "Group \"#{group}\" on line #{index} OK"}
        else
          results << {:error, "Invalid group \"#{group}\" on line #{index}, should be one of: #{@valid_groups}"}
        end
        index += 1
      end
      results
    end

    def validate_gender(input)
      index = 1
      results = [] of {Symbol, String}
      csv = CSV.new(input, headers: true)
      csv.each do |row|
        gender = row["gender"].strip
        if VALID_GENDERS.includes?(gender)
          results << {:ok, "Gender #{gender} on line #{index} OK"}
        else
          results << {:error, "Invalid gender entry \"#{gender}\" on line #{index}, should be one of: #{VALID_GENDERS}"}
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
          results << {:error, "Invalid birth_year found on line #{index}, expected a number but found: #{row["birth_year"]}"}
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
        ->(x : String) { validate_gender(x) },
        ->(x : String) { validate_birth_year(x) }
      ]

      validators.map do |validator|
        validator.call(input)
      end.flatten
    end

    def generate_username(first_name, last_name, first_chars = 6, last_chars = 2)
      first = first_name.downcase.delete(" \-")[0..(first_chars - 1)]
      last = last_name.downcase.delete(" \-")[0..(last_chars - 1)]
      username = "#{first}#{last}"
      if @usernames_count.has_key?({first, last})
        @usernames_count[{first, last}] += 1
        "#{username}#{@usernames_count[{first, last}]}"
      else
        @usernames_count[{first, last}] = 0
        username
      end

    end

    def load_file(filename)
      if File.readable?(filename)
        begin
          input = File.read(filename)

          csv = CSV.new(input, headers: true)
          csv.each {|x| }
          input
        rescue e : CSV::MalformedCSVError
          CSVParserErrors.new("Invalid input file: #{e.message}")
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
                      "birth_year" => row["birth_year"].strip
                     }

        username = generate_username(row["first name"].scrub.strip,
                                     row["last name"].scrub.strip,
                                     1,
                                     6)

        user = User.new(username,
                        row["first name"].scrub.strip,
                        row["last name"].scrub.strip,
                        row["email"].scrub.strip,
                        [row["group"].scrub.strip],
                        attributes)

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

          raise CSVParserErrors.new("Error(s) detected while parsing the CSV input file: ", errors)
        end

      when CSVParserErrors
        raise string_or_error
      end
    end
  end
end
