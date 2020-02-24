require "clim"
require "logger"

module KeycloakCsvUserImport
  class Cli < Clim
    main do
      desc "INS User import tool."
      usage "ins-user-import [options] [arguments] ..."
      version KeycloakCsvUserImport::VERSION
      help short: "-h"
      option "-s SERVER", "--server=SERVER", type: String, desc: "The Keycloak server hostname or IP address", default: "login.localnet"
      option "-p PORT", "--port=PORT", type: Int32, desc: "The Keycloak server port", default: 8443
      option "-u USERNAME", "--username=USERNAME", type: String, desc: "Your Keycloak username.", required: true
      option "-i FILENAME", "--input=FILENAME", type: String, desc: "Input CSV filename.", required: true
      option "-o FILENAME", "--output=FILENAME", type: String, desc: "Output filename", default: "-"
      run do |opts, args|
        begin
          logger = Logger.new(STDOUT, level: Logger::DEBUG)
          csvparser = KeycloakCsvUserImport::CSVParser.new(logger)
          keycloak = KeycloakCsvUserImport::KeycloakAPI.new(logger, opts.server, opts.port, opts.username, "test", "school")

          users = csvparser.parse(opts.input)

          results = keycloak.add_users(users)

          puts "Users: #{users}"

          puts "Results: #{results}"
        rescue e : KeycloakCsvUserImport::CSVParserErrors
          STDERR.puts "Caught error: #{e}"
        end
      end
    end
  end
end
