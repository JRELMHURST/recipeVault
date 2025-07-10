export const SubscriptionService = {
  isPaid: (tier: string): boolean => {
    return ["home_chef", "master_chef"].includes(tier);
  },

  isTrialActive: (userData: any): boolean => {
    const started = userData?.trialStarted;
    const used = userData?.trialUsed === true;

    if (!started || used) return false;

    const trialStart = new Date(started);
    const trialEnd = new Date(trialStart);
    trialEnd.setDate(trialStart.getDate() + 7);

    return new Date() <= trialEnd;
  },
};
