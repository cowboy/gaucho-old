# A wrapper for Grit::Repo
module Gaucho
  class Repo
    attr_reader :repo_path, :repo
    attr_accessor :default_branch, :subdir, :fs_treeish

    def initialize(repo_path, options = {})
      @repo_path = repo_path
      @repo = Grit::Repo.new(repo_path)

      # Initialize from options, overriding these defaults.
      {
        default_branch: 'master', # TODO: MAKE THIS WORK
        subdir: 'content',
        fs_treeish: '__fs__'
      }.merge(options).each {|k,v| self.send("#{k}=".to_sym, v)}
    end

    # A Gaucho::Content instance.
    def content(*args)
      Gaucho::Content.new(self, *args)
    end

    # All Gaucho::Content instances.
    def contents(*args)
      tree = subdir ? repo.tree/subdir : repo.tree
      tree.trees.collect do |tree|
        Gaucho::Content.new(self, tree.name, *args)
      end
    end

    ## TODO: WRITE THIS
    def categories
      contents.each do |content|
        pp content.meta
      end
    end

    ## Get a full SHA from a treeish. (TODO: REMOVE?)
    def rev_parse(treeish)
      repo.git.native(:rev_parse, {raise: true}, treeish) rescue nil
    end
  end
end
