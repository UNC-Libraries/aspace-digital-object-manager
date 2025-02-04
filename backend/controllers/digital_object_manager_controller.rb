# frozen_string_literal: true

class ArchivesSpaceService < Sinatra::Base
  # See README for csv specifications
  Endpoint.post('/repositories/:repo_id/digital_object_manager')
          .description("Creates and deletes managed DOs")
          .params(["repo_id", :repo_id],
                  ["digital_content", :body_stream, "The CSV listing digital content record metadata"],
                  ["source", String, "Content source, either 'dcr' or 'cdm'"],
                  ["delete", String, "Scope of deletions for records missing from csv, either 'global' or 'none' (default)", :default => 'none'],
                  ["deletion_threshold", Integer, "Minimum submitted record count required to allow deletion", :default => nil])
          .permissions([:update_digital_object_record, :delete_archival_record])
          .use_transaction(false)
          .returns([200, :created],
                  [400, :error],
                  [500, :error]) \
  do
    ## stream handling from ArchivesSpace: backend\app\controllers\batch_import.rb
    stream = params[:digital_content]
    tempfile = ASUtils.tempfile('import_stream')

    begin
      while !(buf = stream.read(4096)).nil?
        tempfile.write(buf)
      end
    ensure
      tempfile.close
    end
    #########

    manager = ArchivesSpace::DigitalObjectManager.new(source: params[:source], repo_id: params[:repo_id])
    response = manager.handle_datafile(tempfile, deletion_scope: params[:delete], deletion_threshold: params[:deletion_threshold])

    if response[:client_errors]
      json_response(response, 400)
    elsif response [:server_errors]
      json_response(response, 500)
    else
      json_response("Digital content data successfully processed")
    end
  end
end
