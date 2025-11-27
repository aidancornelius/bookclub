# frozen_string_literal: true

module Bookclub
  class PagesController < BaseController
    skip_before_action :ensure_logged_in, only: %i[index show nav], raise: false
    before_action :ensure_admin, only: %i[create update destroy reorder]
    before_action :find_page, only: %i[show update destroy]

    # GET /bookclub/pages
    # List all pages (admin) or visible pages (public)
    def index
      pages = if guardian.is_admin?
                BookclubPage.ordered
              else
                BookclubPage.visible.ordered
              end

      render json: {
        pages: serialize_data(pages, BookclubPageSerializer, scope: guardian)
      }
    end

    # GET /bookclub/pages/nav
    # Get pages structured for navigation
    def nav
      header_tree = BookclubPage.nav_tree('header')
      footer_tree = BookclubPage.nav_tree('footer')

      render json: {
        header: serialize_nav_tree(header_tree),
        footer: serialize_nav_tree(footer_tree)
      }
    end

    # GET /bookclub/pages/:slug
    def show
      unless @page.visible || guardian.is_admin?
        raise Discourse::NotFound
      end

      render json: {
        page: BookclubPageSerializer.new(@page, scope: guardian, root: false)
      }
    end

    # POST /bookclub/pages
    def create
      page = BookclubPage.new(page_params)

      if page.save
        render json: {
          page: BookclubPageSerializer.new(page, scope: guardian, root: false)
        }
      else
        render json: { errors: page.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PUT /bookclub/pages/:slug
    def update
      if @page.update(page_params)
        render json: {
          page: BookclubPageSerializer.new(@page, scope: guardian, root: false)
        }
      else
        render json: { errors: @page.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /bookclub/pages/:slug
    def destroy
      @page.destroy!
      render json: { success: true }
    end

    # POST /bookclub/pages/reorder
    def reorder
      params[:pages].each do |page_data|
        page = BookclubPage.find(page_data[:id])
        page.update!(
          position: page_data[:position],
          parent_id: page_data[:parent_id]
        )
      end

      render json: { success: true }
    end

    private

    def find_page
      @page = BookclubPage.find_by!(slug: params[:slug])
    end

    def page_params
      params.require(:page).permit(
        :title,
        :slug,
        :raw,
        :parent_id,
        :position,
        :nav_position,
        :visible,
        :show_in_nav,
        :icon
      )
    end

    def ensure_admin
      raise Discourse::InvalidAccess unless guardian.is_admin?
    end

    def serialize_nav_tree(tree)
      tree.map do |item|
        {
          page: BookclubNavPageSerializer.new(item[:page], scope: guardian, root: false),
          children: item[:children].map do |child|
            BookclubNavPageSerializer.new(child, scope: guardian, root: false)
          end
        }
      end
    end
  end
end
