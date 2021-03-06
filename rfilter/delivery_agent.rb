=begin
   Copyright (C) 2001, 2002, 2003 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'rmail/message'
require 'rmail/parser'
require 'rfilter/deliver'
require 'rfilter/mta'

module RFilter

  # The <tt>RFilter::DeliveryAgent</tt> class allows flexible delivery of
  # a mail message to a mailbox.  It is designed to make mail
  # filtering scripts easy to write, by allowing the filter author to
  # concentrate on the filter logic and not the particulars of the
  # message or folder format.
  #
  # It is designed primarily to work as an DeliveryAgent (local
  # delivery agent) for an SMTP server.  It should work well as the
  # basis for a script run from a <tt>.forward</tt> or <tt>.qmail</tt>
  # file.
  class DeliveryAgent
    include RFilter::Deliver

    # A DeliveryComplete exception is one that indicates that
    # RFilter::DeliveryAgent's delivery process is now complete and.  The
    # DeliveryComplete exception is never thrown itself, but its
    # various subclasses are.
    class DeliveryComplete < StandardError
      # Create a new DeliveryComplete exception with a given +message+.
      def initialize(message)
	super
      end
    end

    # This exception is raised when there is a problem logging.
    class LoggingError < StandardError
      attr_reader :original_exception
      def initialize(message, original_exception = nil)
	super(message)
	@original_exception = original_exception
      end
    end

    # Raised when the command run by #pipe or #filter fails.
    class DeliveryCommandFailure < DeliveryComplete
      # This is the exit status of the pipe command.
      attr_reader :status
      def initialize(message, status)
	super(message)
	@status = status
      end
    end

    # Raised upon delivery success, unless the +continue+ flag of the
    # <tt>RFilter::DeliveryAgent</tt> delivery method was set to true.
    class DeliverySuccess < DeliveryComplete
      def initialize(message)
	super
      end
    end

    # Raised by <tt>RFilter::DeliveryAgent#reject</tt>.
    class DeliveryReject < DeliveryComplete
      def initialize(message)
	super
      end
    end

    # Raised by <tt>RFilter::DeliveryAgent#defer</tt>.
    class DeliveryDefer < DeliveryComplete
      def initialize(message)
	super
      end
    end

    # Create a new <tt>RFilter::DeliveryAgent</tt> object.
    #
    # +input+ may be a <tt>RMail::Message</tt> object (in which case,
    # it is used directly).  Otherwise, it is passed to
    # <tt>RMail::Message.new</tt> and used to create a new
    # <tt>RMail::Message</tt> object.
    #
    # +log+ may be nil (to disable logging completely) or a file name
    # to which log messages will be appended.
    def initialize(input, logfile)
      @logfile =
	if logfile.nil?
	  nil
	else
	  File.open(logfile, File::CREAT|File::APPEND|File::WRONLY, 0600)
	end
      @message = if input.is_a?(RMail::Message)
		   input
		 else
		   RMail::Parser.new.parse(input)
		 end
      @logging_level = 2
    end

    # Save this message to mail folder.  +folder+ must be the file
    # name of the mailbox.  If +folder+ ends in a slash (/) then the
    # mailbox will be considered to be in Maildir format, otherwise it
    # will be a Unix mbox folder.
    #
    # If +continue+ is false (the default), a
    # <tt>RFilter::DeliveryAgent::DeliverySuccess</tt> exception is raised upon
    # successful delivery.  Otherwise, the method simply returns upon
    # successful delivery.
    #
    # Upon failure, the function raises an exception as determined by
    # RFilter::Deliver.deliver_mbox or RFilter::Deliver.deliver_maildir.
    #
    # See also: <tt>RFilter::Deliver.deliver_mbox</tt> and
    # <tt>RFilter::Deliver.deliver_maildir</tt>.
    def save(folder, continue = false)
      log(2, "Action: save to #{folder.inspect}")
      retval = if folder =~ %r{(.*[^/])/$}
                 deliver_maildir($1, @message)
               else
                 deliver_mbox(folder, @message)
               end
      raise DeliverySuccess, "saved to mbox #{folder.inspect}" unless continue
      retval
    end

    # Reject this message.  Logs the +reason+ for the rejection and
    # raises a <tt>RFilter::DeliveryAgent::DeliveryReject</tt> exception.
    def reject(reason = nil)
      log(2, "Action: reject: " + reason.to_s)
      raise DeliveryReject.new(reason.to_s)
    end

    # Reject this message for now, but request that it be queued for
    # re-delivery in the future.  Logs the +reason+ for the rejection
    # and raises a <tt>RFilter::DeliveryAgent::DeliveryDefer</tt>
    # exception.
    def defer(reason = nil)
      log(2, "Action: defer: " + reason.to_s)
      raise DeliveryDefer.new(reason.to_s)
    end

    # Pipe this message to a command.  +command+ must be a string
    # specifying a command to pipe the message to.
    #
    # If +continue+ is false, then a successful delivery to the pipe
    # will raise a <tt>RFilter::DeliveryAgent::DeliverySuccess</tt>
    # exception.  If +continue+ is true, then a successful delivery
    # will simply return.  Regardless of +continue+, a failure to
    # deliver to the pipe will raise a
    # <tt>RFilter::DeliveryAgent::DeliveryCommandFailure</tt> exception.
    #
    # See also: <tt>RFilter::Deliver.deliver_pipe.</tt>
    def pipe(command, continue = false)
      log(2, "Action: pipe to #{command.inspect}")
      deliver_pipe(command, @message)
      if $? != 0
	m = "pipe failed for command #{command.inspect}"
        log(1, "Error: " + m)
	raise DeliveryCommandFailure.new(m, $?)
      end
      unless continue
	raise DeliverySuccess.new("pipe to #{command.inspect}")
      end
    end

    # Filter this message through a command.  +command+ must be a
    # string or an array of strings specifying a command to filter the
    # message through (it is passed to the Kernel::exec method).
    #
    # If the command does not exit with a status of 0, a
    # DeliveryCommandFailure exception is raised and the current
    # message is not replaced.
    #
    # See also: <tt>RFilter::Deliver.deliver_filter.</tt>
    def filter(*command)
      log(2, "Action: filter through #{command.inspect}")
      msg = nil
      status = deliver_filter(@message, *command) { |io|
        msg = RMail::Parser.new.parse(io)
      }
      if status != 0
	m = format("filter failed for command %s (status %s)",
                   command.inspect, status.inspect)
        log(1, "Error: " + m)
	raise DeliveryCommandFailure.new(m, status)
      end
      @message = msg
    end

    # Log a string to the log.  If the current log is nil or +level+
    # is greater than the current logging level, then the string will
    # not be logged.
    #
    # See also #logging_level, #logging_level=
    def log(level, str)
      if level <= 0 and @logfile.nil?
	raise LoggingError, "failed to log high priority message: #{str}"
      end
      return if @logfile.nil? or level > @logging_level
      begin
	@logfile.flock(File::LOCK_EX)
	@logfile.print(Time.now.strftime("%Y/%m/%d %H:%M:%S "))
	@logfile.print(sprintf("%05d: ", Process.pid))
	@logfile.puts(str)
	@logfile.flush
	@logfile.flock(File::LOCK_UN)
      rescue
	# FIXME: this isn't tested
	raise LoggingError.new("failed to log message: #{str}", $!)
      end
    end

    # Return the current logging level.
    #
    # See also: #logging_level=, #log
    def logging_level
      @logging_level
    end

    # Set the current logging level.  The +level+ must be a number no
    # less than one.
    #
    # See also: #logging_level, #log
    def logging_level=(level)
      level = Integer(level)
      raise ArgumentError, "invalid logging level value #{level}" if level < 1
      @logging_level = level
    end

    # Return the <tt>RMail::Message</tt> object associated with this
    # <tt>RFilter::DeliveryAgent</tt>.
    #
    # See also: #header, #body
    def message
      @message
    end

    # Sets the message (which should be a RMail::Message object) that
    # we're delivering.
    def message=(message)
      @message = message
    end

    # Return the header of the message as a <tt>RMail::Header</tt> object.
    # This is short hand for <tt>lda.message.header</tt>.
    #
    # See also: #message, #body
    def header
      @message.header
    end

    # Return the body of the message as an array of strings.  This is
    # short hand for <tt>lda.message.body</tt>.
    #
    # See also: #message, #header
    def body
      @message.body
    end

    class << self

      # Takes the same input as #new, but passes the created
      # <tt>RFilter::DeliveryAgent</tt> to the supplied block.  The idea
      # is that the entire delivery script is contained within the
      # block.
      #
      # This function tries to log exceptions that aren't
      # DeliveryComplete exceptions to the lda's log.  If it can log
      # them, it defers the delivery.  But if it can't, it re-raises
      # the exception so the caller can more properly deal with the
      # exception.
      #
      # Expected use:
      #
      #  begin
      #    RFilter::DeliveryAgent.process(stdin, "my-log-file") { |lda|
      #      # ...code uses lda to deliver mail...
      #    }
      #  rescue RFilter::DeliveryAgent::DeliveryComplete => exception
      #    exit(RFilter::DeliveryAgent.exitcode(exception))
      #  rescue Exception
      #    ... perhaps log the exception to a hard coded file ...
      #    exit(RFilter::MTA::EX_TEMPFAIL)
      #  end
      def process(input, logfile)
	begin
	  lda = RFilter::DeliveryAgent.new(input, logfile)
	  yield lda
	  lda.defer("finished without a final delivery")
	rescue Exception => exception
	  if exception.class <= DeliveryComplete
	    raise exception
	  else
	    begin
	      lda.log(0, "uncaught exception: " + exception.inspect)
	      lda.log(0, "uncaught exception backtrace:\n    " +
		      exception.backtrace.join("\n    "))
	      lda.defer("uncaught exception")
	    rescue Exception
	      if $!.class <= DeliveryComplete
		# The lda.defer above will generate this, just re-raise
		# the delivery status exception.
		raise
	      else
		# Any errors logging in the uncaught exception and we
		# just re-raise the original exception
		raise exception
	      end
	    end
	  end
	end
      end

      # This function expects the +exception+ argument to be a
      # RFilter::DeliveryAgent::DeliveryComplete subclass.  The function
      # will return the appropriate exitcode that the process should
      # exit with.
      def exitcode(exception)
	case exception
	when DeliverySuccess
	  RFilter::MTA::EXITCODE_DELIVERED
	when DeliveryReject
	  RFilter::MTA::EXITCODE_REJECT
	when DeliveryComplete
	  RFilter::MTA::EXITCODE_DEFER
	else
	  raise ArgumentError,
	    "argument is not a DeliveryComplete exception: " +
	    "#{exception.inspect} (#{exception.class})"
	end
      end

    end

  end
end

