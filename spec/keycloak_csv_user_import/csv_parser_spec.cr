
require "../spec_helper"
require "../../src/keycloak_csv_user_import/csv_parser"

describe KeycloakCsvUserImport::CSVParser do

  it "validates a header line" do
    kcsv = KeycloakCsvUserImport::CSVParser.new

    kcsv.validate_header_line(CSV.new(File.read("spec/fixtures/good_header.csv"), headers: true)).first.should eq(:ok)
    kcsv.validate_header_line(CSV.new(File.read("spec/fixtures/bad_header.csv"), headers: true)).first.should eq(:error)
  end

  it "validates a file is CSV and readable" do
    kcsv = KeycloakCsvUserImport::CSVParser.new
    kcsv.load_file("spec/fixtures/good_header.csv").should be_a(CSV)

    kcsv.load_file("spec/fixtures/bad_csv.csv").should be_a(KeycloakCsvUserImport::CSVParserErrors)

    kcsv.load_file("spec/fixtures/does_not_exist.csv").should be_a(KeycloakCsvUserImport::CSVParserErrors)
  end

  it "parses a file" do
    kcsv = KeycloakCsvUserImport::CSVParser.new
    kcsv.parse("spec/fixtures/good_file_en.csv").should be_a Array(KeycloakCsvUserImport::User)

  end
end
