module spreadly::vote_type {
    public enum VoteType has store, copy, drop {
        For,
        Against,
        Abstain
    }

    // Helper functions for matching
    public fun is_for(vote: &VoteType): bool {
        match (vote) {
            VoteType::For => true,
            _ => false
        }
    }

    public fun is_against(vote: &VoteType): bool {
        match (vote) {
            VoteType::Against => true,
            _ => false
        }
    }

    public fun is_abstain(vote: &VoteType): bool {
        match (vote) {
            VoteType::Abstain => true,
            _ => false
        }
    }
}