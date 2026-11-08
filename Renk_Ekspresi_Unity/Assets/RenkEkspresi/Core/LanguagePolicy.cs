namespace RenkEkspresi
{
    /// <summary>
    /// Decides the interface language. Pure logic (no UnityEngine) so the Verification
    /// project can test it. A language the player chose explicitly always wins; a fresh
    /// install follows the device language, defaulting to English outside Turkish devices
    /// so international App Review and players never land on an unreadable first screen.
    /// </summary>
    public static class LanguagePolicy
    {
        public const string Turkish = "tr";
        public const string English = "en";

        public static bool IsSupported(string language)
        {
            return language == Turkish || language == English;
        }

        public static string Resolve(string saved, bool deviceIsTurkish)
        {
            if (IsSupported(saved))
                return saved;
            return deviceIsTurkish ? Turkish : English;
        }
    }
}
