require 'mail'
require 'concurrent-ruby'
require 'colorize'

def check_smtp_status(smtp_servers, receiver_email)
  working_servers = []
  pool_size = [50, smtp_servers.length].min

  executor = Concurrent::ThreadPoolExecutor.new(
    min_threads: 1,
    max_threads: pool_size,
    max_queue: 0,
    fallback_policy: :caller_runs
  )

  smtp_servers.each do |smtp|
    executor.post do
      domain, port, username, password = smtp.split('|')
      puts "\nTrying #{domain}:#{port}..."

      begin
        options = {
          address: domain,
          port: port.to_i,
          enable_starttls_auto: true,
          openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE,
          user_name: username,
          password: password,
          authentication: (username.nil? || password.nil?) ? nil : 'plain'
        }

        Mail.defaults do
          delivery_method :smtp, options
        end

        mail = Mail.new do
          from username
          to receiver_email
          subject 'SMTP Server Information'
          body "SMTP Server: #{domain}\nPort: #{port}\nUsername: #{username}\nPassword: #{password}"
        end

        mail.deliver!

        working_servers << smtp
        save_working_server(smtp)
        puts "SMTP Server '#{domain}:#{port}' is working.".green
      rescue StandardError => e
        puts "SMTP Server '#{domain}:#{port}' is not working. Error: #{e.message}".red
      end
    end
  end

  executor.shutdown
  executor.wait_for_termination

  working_servers
end

def read_smtp_servers(file_path)
  smtp_servers = File.readlines(file_path, chomp: true)
  smtp_servers.select { |server| server.include?('|') }
end

def save_working_server(smtp_server)
  File.open('workingsmtp.txt', 'a') do |file|
    file.puts(smtp_server) unless File.foreach('workingsmtp.txt').grep(/#{Regexp.escape(smtp_server)}/).any?
  end
end

def main
  logo = <<~LOGO
    ╔═╗╔╦╗╔╦╗╔═╗╔═╗╦ ╦╔═╗╔═╗╦╔═╔═╗╦═╗
    ╚═╗║║║ ║ ╠═╝║  ╠═╣║╣ ║  ╠╩╗║╣ ╠╦╝
    ╚═╝╩ ╩ ╩ ╩  ╚═╝╩ ╩╚═╝╚═╝╩ ╩╚═╝╩╚═
                Fast SMTP Checker
  LOGO

  puts logo.yellow

  print 'Enter the path to the file containing SMTP servers: '
  file_path = gets.chomp

  print "Enter the receiver's email address: "
  receiver_email = gets.chomp

  smtp_servers = read_smtp_servers(file_path)
  working_servers = check_smtp_status(smtp_servers, receiver_email)

  puts "\n--- Working SMTP Servers ---"
  working_servers.each do |server|
    puts server
  end
end

main

