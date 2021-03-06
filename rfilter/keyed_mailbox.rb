#!/usr/bin/env ruby
#--
#   Copyright (C) 2002, 2003 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'rfilter/deliver'
require 'digest/md5'
require 'timeout'

module RFilter

  # A KeyedMailbox object implements a message mailbox indexed by a
  # unique key string for each message.  When a message is saved into
  # the store, the message's key is returned.  Later, the key is used
  # to retrieve file name the message is stored in.
  #
  # The message store has the following characteristics:
  #
  # 1. It is a Maildir, so various mail programs can read the messages
  #    directly and without adversely affecting the mailbox.
  # 2. The key is very hard to guess.
  # 3. The key is short and can be included in a message subject or in
  #    the extension of a return address (suitable for mailing list style
  #    confirmations).
  class KeyedMailbox
    include RFilter::Deliver

    # Creates a confirmation queue object that manages a confirmation
    # queue in directory +path+.
    def initialize(path)
      @path = path.to_str.freeze
    end

    # Saves a message into a confirmation queue and returns a string
    # key that can be used to retrieve it later.  They key is a string
    # of hex digits and dashes, suitable for inclusion in a message
    # subject or "VERP" return address.
    def save(message)
      save_key(message, deliver_maildir(@path, message))
    end

    # Get the file name holding the message associated with +key+, or
    # returns nil if the message is missing.
    def retrieve(key)
      begin
        message_filename(dereference_key(key)).untaint
      rescue Errno::ENOENT
        nil
      end
    end

    # Given a key, delete the message associated with it.
    def delete(key)
      begin
        File.delete(key_filename(key),
                    message_filename(dereference_key(key)))
      rescue Errno::ENOENT
      end
    end

    # Expire messages in the confirmation queue older than +age+ days
    # old.
    def expire(age)
      cutoff = Time.now - (60 * 60 * 24) * age
      [ File.join(@path, 'new', '*'),
        File.join(@path, 'cur', '*'),
        File.join(@path, '.index', '*')].each { |glob|
        Dir[glob].each { |file|
          File::delete(file) if File::mtime(file) <= cutoff
        }
      }
    end

    # Return the path of this keyed mailbox (same value passed in
    # #new).
    def path
      return @path
    end

    private

    def key_filename(key)
      raise ArgumentError, key unless key =~ /^[A-Za-z\d]{10}$/
      File.join(@path, '.index', key.upcase).untaint
    end

    def dereference_key(key)
      IO.readlines(key_filename(key))[0]
    end

    def message_filename(basename)
      raise ArgumentError, basename unless basename =~ /^[\w\.]+$/
      basename.untaint
      catch(:found) {
        [ File.join(@path, 'new', basename),
          File.join(@path, 'cur', basename) ].each { |curr|
          Dir["#{curr}*"].each { |fullname|
            throw(:found, fullname.untaint)
          }
        }
        nil
      }
    end

    def save_key(message, maildir_filename)

      # First make the required directories
      begin
        Dir.mkdir(File.join(@path, '.index'))
      rescue Errno::EEXIST
        raise unless FileTest::directory?(@path)
      end

      hash = nil
      tmp_dir = File.join(@path, 'tmp')
      index_dir = File.join(@path, '.index')
      try_count = 1
      begin
        hash = hash_str(message)
        tmp_name = File.join(tmp_dir, hash)
        index_name = File.join(index_dir, hash)
        File.open(tmp_name, File::CREAT|File::EXCL|File::WRONLY|File::SYNC,
                  0600) { |f|
          f.print(File.basename(maildir_filename))
        }
        File.link(tmp_name, index_name)
      rescue Errno::EEXIST
        raise if try_count >= 5
        sleep(2)
        try_count = try_count.next
        retry
      ensure
        begin
          File.delete(tmp_name) unless tmp_name.nil?
        rescue Errno::ENOENT
        end
      end
      hash
    end

    def hash_str(message)

      # Hash the message, the current time, the current pid and
      # unambiguously separate them with the 0 byte.
      md5 = Digest::MD5::new
      md5.update(Marshal.dump(message))
      md5.update(0.chr)
      md5.update(Time.now.to_s)
      md5.update(0.chr)
      md5.update(Process.pid.to_s)

      # And if we have the last hash we generated, update with the last
      # two bytes of it.
      last_hash_name = File.join(@path, '.last_hash')
      begin
        timeout(10) {
          File.open(last_hash_name, 'rb') { |f|
            f.flock(File::LOCK_SH)
            f.seek(14)
            if last_two = f.read(2)
              md5.update(0.chr)
              md5.update(last_two)
            end
          }
        }
      rescue Errno::ENOENT
      rescue TimeoutError
      end

      hash = md5.digest

      begin
        timeout(10) {
          File.open(last_hash_name, 'wb', 0600) { |f|
            f.flock(File::LOCK_EX)
            f.print(hash)
          }
        }
      rescue TimeoutError
      end

      hash[0..4].unpack("H*")[0].upcase
    end
  end
end
