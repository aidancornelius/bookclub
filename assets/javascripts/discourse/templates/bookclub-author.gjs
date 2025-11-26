import BookclubAuthorDashboard from "discourse/plugins/bookclub/discourse/components/bookclub-author-dashboard";

export default <template>
  <BookclubAuthorDashboard @publications={{@model.publications}} />
</template>
