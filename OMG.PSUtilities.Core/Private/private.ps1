if (-not ('CredentialManager.CredMan' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace CredentialManager
{
    public class CredMan
    {
        // Import Windows API functions from Advapi32.dll
        [DllImport("Advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredWrite([In] ref CREDENTIAL credential, [In] int flags);

        [DllImport("Advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);

        [DllImport("Advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredDelete(string target, int type, int flags);

        [DllImport("Advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
        private static extern bool CredFree(IntPtr credentialPtr);

        [DllImport("Advapi32.dll", EntryPoint = "CredEnumerateW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredEnumerate(string filter, int flag, out int count, out IntPtr credentialPtr);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct CREDENTIAL
        {
            public int Flags;
            public int Type;
            public string TargetName;
            public string Comment;
            public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
            public int CredentialBlobSize;
            public IntPtr CredentialBlob;
            public int Persist;
            public int AttributeCount;
            public IntPtr Attributes;
            public string TargetAlias;
            public string UserName;
        }

        // Store credentials
        public static bool Store(string target, string username, string password, string comment = "")
        {
            byte[] passwordBytes = Encoding.Unicode.GetBytes(password);
            IntPtr passwordPtr = Marshal.AllocHGlobal(passwordBytes.Length);
            Marshal.Copy(passwordBytes, 0, passwordPtr, passwordBytes.Length);

            CREDENTIAL credential = new CREDENTIAL
            {
                Type = 1, // CRED_TYPE_GENERIC
                TargetName = target,
                UserName = username,
                CredentialBlob = passwordPtr,
                CredentialBlobSize = passwordBytes.Length,
                Persist = 2, // CRED_PERSIST_LOCAL_MACHINE
                Comment = comment,
                Flags = 0,
                AttributeCount = 0,
                Attributes = IntPtr.Zero
            };

            bool result = CredWrite(ref credential, 0);
            Marshal.FreeHGlobal(passwordPtr);
            
            return result;
        }

        // Retrieve password
        public static string GetPassword(string target)
        {
            IntPtr credPtr;
            if (CredRead(target, 1, 0, out credPtr))
            {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                string password = Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2);
                CredFree(credPtr);
                return password;
            }
            return null;
        }

        // Retrieve username
        public static string GetUsername(string target)
        {
            IntPtr credPtr;
            if (CredRead(target, 1, 0, out credPtr))
            {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                string username = cred.UserName;
                CredFree(credPtr);
                return username;
            }
            return null;
        }

        // Delete credential
        public static bool Delete(string target)
        {
            return CredDelete(target, 1, 0);
        }

        // List all credentials
        public static System.Collections.Generic.List<string> List()
        {
            var result = new System.Collections.Generic.List<string>();
            int count;
            IntPtr credPtr;
            
            if (CredEnumerate(null, 0, out count, out credPtr))
            {
                for (int i = 0; i < count; i++)
                {
                    IntPtr currentPtr = Marshal.ReadIntPtr(credPtr, i * IntPtr.Size);
                    CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(currentPtr, typeof(CREDENTIAL));
                    result.Add(cred.TargetName);
                }
                CredFree(credPtr);
            }
            return result;
        }

        // Get full credential details
        public static CredentialInfo Get(string target)
        {
            IntPtr credPtr;
            if (CredRead(target, 1, 0, out credPtr))
            {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                long fileTime = ((long)cred.LastWritten.dwHighDateTime << 32) + cred.LastWritten.dwLowDateTime;
                DateTime lastModified = DateTime.FromFileTime(fileTime);
                var info = new CredentialInfo
                {
                    Target = cred.TargetName,
                    Username = cred.UserName,
                    Password = Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2),
                    Comment = cred.Comment,
                    LastModified = lastModified
                };
                CredFree(credPtr);
                return info;
            }
            return null;
        }
    }

    public class CredentialInfo
    {
        public string Target { get; set; }
        public string Username { get; set; }
        public string Password { get; set; }
        public string Comment { get; set; }
        public DateTime LastModified { get; set; }
    }
}
"@
}