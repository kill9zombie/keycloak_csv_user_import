
require "../spec_helper"
require "../../src/keycloak_csv_user_import/csv_parser"

describe KeycloakCsvUserImport::CSVParser do

  it "validates a header line" do
    kcsv = KeycloakCsvUserImport::CSVParser.new

    kcsv.validate_header_line(File.read("spec/fixtures/good_file_en.csv")).first.should eq(:ok)
    kcsv.validate_header_line(File.read("spec/fixtures/bad_header.csv")).first.should eq(:error)
  end

  it "validates a file is CSV and readable" do
    kcsv = KeycloakCsvUserImport::CSVParser.new
    kcsv.load_file("spec/fixtures/good_header.csv").should be_a(String)

    kcsv.load_file("spec/fixtures/bad_csv.csv").should be_a(KeycloakCsvUserImport::CSVParserErrors)

    kcsv.load_file("spec/fixtures/does_not_exist.csv").should be_a(KeycloakCsvUserImport::CSVParserErrors)
  end

  it "parses a file" do
    kcsv = KeycloakCsvUserImport::CSVParser.new
    kcsv.parse("spec/fixtures/good_file_en.csv").should be_a Array(KeycloakCsvUserImport::User)

  end

  it "generates a username" do
    kcsv = KeycloakCsvUserImport::CSVParser.new
    kcsv.generate_username("Alice", "Fleaks", 6, 2).should eq "alicefl"
    kcsv.generate_username("Alice", "Fleaks", 6, 2).should eq "alicefl1"
    kcsv.generate_username("Jean-Marc", "Butterworth", 6, 2).should eq "jeanmabu"
    kcsv.generate_username("Andre", "Mueller-Stahl", 6, 2).should eq "andremu"
    kcsv.generate_username("André", "Clement", 6, 2).should eq "andrécl"
    kcsv.generate_username("Wikus", "Van de merwe", 6, 2).should eq "wikusva"
    kcsv.generate_username("William", "Benjamin", 4, 4).should eq "willbenj"
  end
end
