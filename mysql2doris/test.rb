# frozen_string_literal: true

FLINK_HOME = ENV['FLINK_HOME']
abort 'No flink cluster provided.' if FLINK_HOME.nil?

FLINK_CDC_HOME = ENV['FLINK_CDC_HOME']
abort 'No flink cdc path provided.' if FLINK_CDC_HOME.nil?

puts 'Cleaning jobs...'
puts `cd #{FLINK_HOME} && #{Dir.pwd}/../cancel-all.sh`

SOURCE_PORT = 3306
SINK_HTTP_PORT = 8030
SINK_SQL_PORT = 9030
DATABASE_NAME = 'reicigo'
TABLES = %w[fallen_angel gabriel disenchanted].freeze

def exec_sql_source(sql)
  `mysql -h 127.0.0.1 -P#{SOURCE_PORT} -uroot --skip-password -e "USE #{DATABASE_NAME}; #{sql}" 2>/dev/null`
end

def exec_sql_sink(sql)
  `mysql -h 127.0.0.1 -P#{SINK_SQL_PORT} -uroot --skip-password -e "#{sql}" 2>/dev/null`
end

def count_source
  TABLES.map do |table_name|
    exec_sql_source("SELECT COUNT(*) FROM #{table_name};").split("\n").last.to_i
  end.sum
end

def count_sink
  exec_sql_sink("USE #{DATABASE_NAME}; SELECT COUNT(*) FROM terminus;").split("\n").last.to_i
end

puts 'Waiting for source to start up...'
next until exec_sql_source("SELECT '1';") == "1\n1\n"

puts 'Waiting for sink to start up...'
next until exec_sql_sink("SELECT '1';") == "'1'\n1\n"

puts 'Waiting for sink to start up...'
next until exec_sql_sink('SHOW BACKENDS\\G').include? '*************************** 1. row ***************************'

exec_sql_sink("DROP DATABASE IF EXISTS #{DATABASE_NAME};")
# Doris connector doesn't automatically creates database for now
# See https://issues.apache.org/jira/browse/FLINK-35090
exec_sql_sink("CREATE DATABASE #{DATABASE_NAME};")
puts 'Filling snapshot data...'
exec_sql_source("USE #{DATABASE_NAME}; source #{Dir.pwd}/../snapshot_fill.sql")

puts 'Submitting pipeline job...'
`#{FLINK_CDC_HOME}/bin/flink-cdc.sh pipeline.yaml`

BATCH_SIZE = 17
last_index = 1024

puts 'Start streaming validation...'

loop do
  TABLES.each do |table_name|
    # Provide stream data
    1.upto(BATCH_SIZE) do |i|
      exec_sql_source("INSERT INTO #{table_name} VALUES ('#{table_name}-#{last_index + i}', 'split_#{i}');")
    end

    puts "Example row: \n#{exec_sql_sink("USE #{DATABASE_NAME}; SELECT * FROM terminus LIMIT 1;")}"
    sent = count_source
    received = count_sink
    puts "#Latency: #{sent - received}. #Source: #{sent} => #Sink: #{received}"
    last_index += BATCH_SIZE
  end
end
