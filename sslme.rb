require 'rubygems'
require 'bundler'
Bundler.require(:default)

require 'openssl'
require 'fileutils'

# Based off of https://lolware.net/2015/10/27/letsencrypt_go_live.html
ENDPOINT = 'https://acme-staging.api.letsencrypt.org'
EMAIL = 'mailto:nat@natwelch.com'
DOMAIN = 'sadnat.com'
WEBROOT = '.'

ACCOUNT_FILE = 'account_key.pem'

if File.exist?(ACCOUNT_FILE)
  puts "Using existing account.."
  private_key = OpenSSL::PKey::RSA.new(File.read ACCOUNT_FILE)
  client = Acme::Client.new(private_key: private_key, endpoint: ENDPOINT)
else
  puts "Account file does not exist, creating new"
  private_key = OpenSSL::PKey::RSA.new 4096
  open ACCOUNT_FILE, 'w' do |io|
    io.write private_key.to_pem
  end
  client = Acme::Client.new(private_key: private_key, endpoint: ENDPOINT)
  registration = client.register(contact: EMAIL)
  registration.agree_terms
end

puts 'Creating verification file'
simple_http = client.authorize(domain: DOMAIN).simple_http
filename = File.expand_path(File.join(WEBROOT, simple_http.filename))
FileUtils::mkdir_p File.dirname filename
open filename, 'w' do |io|
  io.write simple_http.file_content
end

simple_http.request_verification
sleep(1) while (simple_http.verify_status == 'pending')
File.delete(WEBROOT + simple_http.filename)

puts 'Status verified, creating certificate'
csr = OpenSSL::X509::Request.new
certificate_private_key = OpenSSL::PKey::RSA.new(2048)
csr.subject = OpenSSL::X509::Name.new([['CN', common_name, OpenSSL::ASN1::UTF8STRING]])

csr.public_key = certificate_private_key.public_key
csr.sign(certificate_private_key, OpenSSL::Digest::SHA256.new)

puts 'Writing out ssl_cert.pem and ssl_private_key.pem'
ssl = client.new_certificate(csr)
open 'ssl_private_key.pem', 'w' do |io|
  io.write certificate_private_key.to_pem
end
open 'ssl_cert.pem', 'w' do |io|
  io.write ssl.to_pem
end
