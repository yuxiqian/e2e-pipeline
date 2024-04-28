# frozen_string_literal: true

TABLES = %w[fallen_angel gabriel disenchanted].freeze
TABLES.each do |table_name|
  puts("DROP TABLE IF EXISTS #{table_name};")
  puts("CREATE TABLE #{table_name} (ID VARCHAR(177) NOT NULL, LOLO VARCHAR(255), PRIMARY KEY (ID));")

  # Provide snapshot data
  1.upto(1024) do |i|
    puts("INSERT INTO #{table_name} VALUES ('#{table_name}-#{i}', 'snapshot_#{i}');")
  end
end
