using System;
namespace RenkEkspresi
{
    // Native SDK implementers must validate StoreKit/Billing entitlements and deliver
    // reward-completed events. Absent SDKs never fabricate a purchase or an ad.
    public interface ICommerce
    {
        bool Vip
        {
            get;
        }
        string Price
        {
            get;
        }
        bool CanBuy
        {
            get;
        }
        bool RewardReady
        {
            get;
        }
        void Buy(Action<bool> done); void Restore(Action<bool> done);
        void Reward(Action<bool> done); void Interstitial(Action done);
    }
    public sealed class UnavailableCommerce : ICommerce
    {
        public bool Vip
        {
            get
            {
                return false;
            }
        }
        public string Price
        {
            get
            {
                return "";
            }
        }
        public bool CanBuy
        {
            get
            {
                return false;
            }
        }
        public bool RewardReady
        {
            get
            {
                return false;
            }
        }
        public void Buy(Action<bool> done)
        {
            done(false);
        }
        public void Restore(Action<bool> done)
        {
            done(false);
        }
        public void Reward(Action<bool> done)
        {
            done(false);
        }
        public void Interstitial(Action done)
        {
            done();
        }
    }
    public sealed class RewardGuard
    {
        int generation; bool pending;
        public int Begin()
        {
            pending = true;
            return ++generation;
        }
        public void Cancel()
        {
            pending = false;
            generation++;
        }
        public bool Accept(int token, bool earned)
        {
            if (!pending || token != generation)
                return false;
            pending = false;
            return earned;
        }
    }
}
