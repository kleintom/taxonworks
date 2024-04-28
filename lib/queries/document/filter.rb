module Queries
  module Document
    class Filter < Query::Filter

      PARAMS = [
        :document_id,
        :file_extension,
        document_id: [],
      ].freeze

      attr_accessor :document_id

      attr_accessor :file_extension

      def initialize(query_params)
        super

        @document_id = params[:document_id]
        @file_extension = params[:file_extension]
      end

      def document_id
        [@document_id].flatten.compact
      end

      def file_extension_facet
        d = EXTENSIONS_DATA[file_extension&.to_sym] || {
          content_type: '', # matches no document
          extensions: ['']
        }

        type_match = table[:document_file_content_type].eq(d[:content_type])

        extensions_match = extension_matches_ored(d[:extensions])

        type_match.and(extensions_match)
      end

      def and_clauses
        [file_extension_facet]
      end

      private

      EXTENSIONS_DATA = {
        '.nex, .nxs': {
          content_type: 'text/plain',
          extensions: ['.nex', '.nxs']
        },
        '.pdf': {
          content_type: 'application/pdf',
          extensions: ['.pdf']
        }
      }.freeze

      def extension_matches_ored(exts)
        clauses = exts.map { |ext|
          table[:document_file_file_name].matches('%' + ext)
        }

        a = clauses.shift
        clauses.each do |b|
          a = a.or(b)
        end
        a
      end
    end
  end
end