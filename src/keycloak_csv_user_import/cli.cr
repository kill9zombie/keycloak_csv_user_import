require "clim"
require "logger"

module KeycloakCsvUserImport
  class CliError < Exception; end
  class Cli < Clim

    main do
      desc "INS User import tool."
      usage "ins-user-import [options] [arguments] ..."
      version KeycloakCsvUserImport::VERSION
      help short: "-h"
      option "-s SERVER", "--server=SERVER", type: String, desc: "The Keycloak server hostname or IP address", default: "login.localnet"
      option "-r REALM", "--realm=REALM", type: String, desc: "The Keycloak realm", default: "school"
      option "-p PORT", "--port=PORT", type: Int32, desc: "The Keycloak server port", default: 8443
      option "-u USERNAME", "--username=USERNAME", type: String, desc: "Your Keycloak username.", required: true
      option "-i FILENAME", "--input=FILENAME", type: String, desc: "Input CSV filename.", required: true
      option "-o FILENAME", "--output=FILENAME", type: String, desc: "Output filename", default: "-"
      option "-d", "--debug", type: Bool, desc: "Debug mode"
      run do |opts, args|
        begin

          logger_level = if opts.debug
                           Logger::DEBUG
                         else
                           Logger::ERROR
                         end

          logger = Logger.new(STDOUT, level: logger_level)

          password = if STDIN.tty?
            print "Enter Password: "
            STDIN.noecho &.gets.try &.chomp
          else
            STDIN.gets
          end
          puts

          raise KeycloakCsvUserImport::CliError.new("A password must be provided") if password.is_a?(Nil)

          keycloak = KeycloakCsvUserImport::KeycloakAPI.new(logger, opts.server, opts.port, opts.username, password, opts.realm)

          groups = if keycloak.has_token?
                     keycloak.get_all_groups
                   else
                     keycloak.update_access_token
                     keycloak.get_all_groups
                   end

          csvparser = KeycloakCsvUserImport::CSVParser.new(groups, logger)

          users = csvparser.parse(opts.input)

          results = keycloak.add_users(users)

          io = if opts.output == "-"
                 STDOUT
               else
                 logger.debug "Writing to #{opts.output}"
                 File.new(opts.output, "w+")
               end

          output = KeycloakCsvUserImport::Output.new

          output.write(io, results)
          io.close
        rescue e : KeycloakCsvUserImport::CSVParserErrors
          STDERR.puts e.message
          e.errors.each do |err|
            STDERR.puts "  #{err}"
          end
        end
      end
    end
  end
end
