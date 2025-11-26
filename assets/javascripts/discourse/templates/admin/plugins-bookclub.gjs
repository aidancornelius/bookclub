import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-plugin-bookclub">
    <h1>
      {{icon "book-open"}}
      {{i18n "bookclub.admin.title"}}
    </h1>

    <div class="admin-plugin-content">
      <p>
        Bookclub is configured through category settings. To set up a
        publication:
      </p>

      <ol>
        <li>Create or edit a category</li>
        <li>Enable "Publication" in the category settings</li>
        <li>Configure the publication type, access tiers, and other settings</li>
        <li>Create topics within the category as chapters/articles</li>
      </ol>

      <h2>Site settings</h2>
      <p>
        Configure Bookclub behaviour in
        <a href="/admin/site_settings/category/plugins?filter=bookclub">
          Site Settings &rarr; Plugins &rarr; Bookclub
        </a>
      </p>

      <h2>Resources</h2>
      <ul>
        <li>
          <a href="/library">Library</a>
          - View all publications
        </li>
        <li>
          <a href="/bookclub/author">Author dashboard</a>
          - Manage your publications
        </li>
      </ul>
    </div>
  </div>
</template>
