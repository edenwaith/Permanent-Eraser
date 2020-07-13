#include <string>
#include <set>

#include <cassert>
#include <unistd.h>

#include <srm.h>
#include <impl.h>

static int delFn(const std::string& fn, const int options)
{
  int z=0, flag=FTS_F;

  struct stat statbuf;
  if(lstat(fn.c_str(), &statbuf) == 0)
  {
    if(S_ISDIR(statbuf.st_mode))
    {
      std::string spec=fn; spec+="\\*.*";

      struct _finddata_t fileinfo;
      intptr_t h=_findfirst(spec.c_str(), &fileinfo);
      if(h == -1) return -1;

      do
      {
	std::string fi=fileinfo.name;
        if(fi!="." && fi!="..")
          z+=delFn(fn+'\\'+fi, options);
      } while(_findnext(h, &fileinfo) == 0);
      _findclose(h);

      flag=FTS_DP;
    }
  }

  process_file(const_cast<char*>(fn.c_str()), flag, options);
  return ++z;
}

extern "C" int tree_walker(char **trees, const int options)
{
  int i = 0;
  assert(trees);

  while (trees[i] != NULL)
  { 
    while (trees[i][strlen(trees[i]) - 1] == SRM_DIRSEP)
      trees[i][strlen(trees[i]) -1] = '\0';

    delFn(trees[i++], options);
  }
  return 0;
}
