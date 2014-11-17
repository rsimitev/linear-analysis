!> Reads a file with the number of modes and a list of files
!! containing said modes for different parameters,
!! one file per line.
program modeTracker
   implicit none
   integer, parameter:: unitFileList=15, degree=4
   character(len=128):: listFileName, fileToRead
   character(len=256):: line
   double precision:: par(degree)
   double precision, allocatable:: modes(:,:)
   double precision:: newPar, projectedModeVal, projectedModeValJ
   double precision, allocatable:: newModeSet(:)
   integer:: nModes !< the number of modes to be read from each file
   integer:: nFile !< The index of the modes file read
   integer:: info, i, j


   call init(info)

   ! We need to read one file at a time and recompute the fit.
   do
      call readLineOfFilesToRead(unitFileList, line, info)
      if(info.ne.0) exit
      nFile = nFile + 1
      ! Shift the parameter and mode pointers to the next value
      read(line,*) newPar, fileToRead
      ! Read one file at a time
      call readModesFile(trim(fileToRead), newModeSet)
      ! Now that we have the next parameter value and the
      ! next set of modes, we reorder it.
      do i=1, nModes-1
         ! For each mode, we compute the projected mode value
         projectedModeVal = nextPoint3(par, modes(i,:), newPar)
         ! Reorder the newly read mode set according to the distance to the
         ! projected value
         do j=1, nModes
            if(abs(projectedModeVal-newModeSet(j)).lt.abs(projectedModeVal-newModeSet(i))) then
               projectedModeValJ = nextPoint3(par, modes(j,:), newPar)
               if(abs(projectedModeValJ-newModeSet(i)).lt.abs(projectedModeValJ-newModeSet(j))) then
                  call swap(newModeSet(i),newModeSet(j))
               endif
            endif
         enddo
      enddo
      par(mod(nFile-1,degree)+1)     = newPar
      modes(:,mod(nFile-1,degree)+1) = newModeSet(:)
      ! Now that things are in proper order, we need to save the new set of modes to file
      call saveReorderedModeSet(newModeSet, nModes)
      ! and then add it to the modes that are going to be used for interpolation
      ! in the next iteration.
   enddo

   call cleanup()
contains

   !**********************************************************************
   !> Initialize stuff
   !**********************************************************************
   subroutine init(info)
      implicit none
      integer:: info

      call getarg(1,listFileName)
      if (listFileName.eq.' ' .or. listFileName.eq.'-h') then
         print*, 'Usage : '
         print*, 'modeTracker <list file>'
         stop
      endif

      open(unit=unitFileList, file=trim(listFileName), status='OLD', iostat=info)
      if (info.ne.0) call MTabort(info)

      ! Read the number of modes
      read(unitFileList,*) nModes

      allocate(modes(nModes,degree),newModeSet(nModes))
      modes = 0.0d0

      ! Read three files so we can make the first quadratic fit.
      nFile = 0
      do
         call readLineOfFilesToRead(unitFileList, line, info)
         if(info.ne.0) exit
         Write(*,*) line
         ! Read one file at a time
         nFile = nFile + 1
         read(line,*) par(nFile), fileToRead
         call readModesFile(fileToRead, modes(:,nFile))
         call saveReorderedModeSet(modes(:,nFile), nModes)
         if (nFile==degree) exit
      enddo
   end subroutine

   !**********************************************************************
   !> Reads a file one line at a time until it finds one that
   !! does not start with a '#'.
   !**********************************************************************
   subroutine readLineOfFilesToRead(unitFileList,line, info)
      implicit none
      character(len=*), intent(out):: line
      integer, intent(in):: unitFileList
      integer, intent(out):: info
      info=0
      do
         read(unitFileList,'(A)', iostat=info) line
         if (info.ne.0) exit
         line = adjustl(line)
         if (line(1:1).ne.'#') exit
      enddo
   end subroutine

   !**********************************************************************
   !> Read all the growth rates from one file.
   !**********************************************************************
   subroutine readModesFile(fileToRead, modes)
      implicit none
      character(len=*), intent(in):: fileToRead
      double precision, intent(out):: modes(:)
      character(len=128):: line
      double precision:: modeVal, modeFreq
      integer:: n, readStatus

      readStatus = 0
      modes = 0.0d0
      open(unit=20, file=fileToRead, status='OLD')

      do
         ! Read one line at a time
         read(20,'(A)', iostat=readStatus) line
         ! Exit on error
         if(readStatus.ne.0) exit
         ! Check if this is a comment and cycle if it is.
         line = adjustl(line)
         if (line(1:1).eq.'#') cycle
         ! Read the mode index and the value
         read(line,*) n, modeFreq, modeVal
         if (n.gt.nModes) exit
         modes(n) = modeVal
      enddo

      close(unit=20)
   end subroutine

   !**********************************************************************
   !> Given three points of coordinates xOld, yOld, extimate the next point at x.
   !**********************************************************************
   function nextPoint3(xOld,yOld,x) result(y)
      implicit none
      double precision:: y
      double precision, intent(in):: xOld(degree), yOld(degree), x
      double precision:: a,b,c,d, x1, x2, x3, y1, y2, y3

      x1 = xOld(1)
      x2 = xOld(2)
      x3 = xOld(3)
      y1 = yOld(1)
      y2 = yOld(2)
      y3 = yOld(3)

      d = (x2-x1)*(x3-x1)*(x3-x2)
      a = ( (x2-x1)*y3 - (x3-x1)*y2 + (x3-x2)*y1 )/d
      b =-( (x2**2-x1**2)*y3 - (x3**2-x1**2)*y2 + (x3**2-x2**2)*y1 )/d
      c = ( (x2 - x1)*x1*x2*y3 - (x3 - x1)*x1*x3*y2 + (x3 - x2)*x2*x3*y1 )/d

      y = a*x**2 + b*x + c
   end function

   !**********************************************************************
   !> Given four points of coordinates xOld, yOld, extimate the next point at x.
   !**********************************************************************
   function nextPoint4(xOld,yOld,x) result(y)
      implicit none
      double precision:: y
      double precision, intent(in):: xOld(degree), yOld(degree), x
      double precision:: a,b,c,d, x1, x2, x3, x4, y1, y2, y3, y4

      x1 = xOld(1)
      x2 = xOld(2)
      x3 = xOld(3)
      x4 = xOld(4)
      y1 = yOld(1)
      y2 = yOld(2)
      y3 = yOld(3)
      y4 = yOld(4)

      a = ( ((x2-x1)*x3**2+(x1**2-x2**2)*x3+x1*x2**2-x1**2*x2)*y4 + &
            ((x1-x2)*x4**2+(x2**2-x1**2)*x4-x1*x2**2+x1**2*x2)*y3 + &
            ((x3-x1)*x4**2+(x1**2-x3**2)*x4+x1*x3**2-x1**2*x3)*y2 + &
            ((x2-x3)*x4**2+(x3**2-x2**2)*x4-x2*x3**2+x2**2*x3)*y1 )/( &
            ((x2-x1)*x3**2+(x1**2-x2**2)*x3+x1*x2**2-x1**2*x2)*x4**3 + &
            ((x1-x2)*x3**3+(x2**3-x1**3)*x3-x1*x2**3+x1**3*x2)*x4**2 + &
            ((x2**2-x1**2)*x3**3+(x1**3-x2**3)*x3**2+x1**2*x2**3-x1**3*x2**2)*x4 + &
             (x1**2*x2-x1*x2**2)*x3**3 + &
             (x1* x2**3-x1**3*x2)*x3**2 + &
             (x1**3*x2**2-x1**2*x2**3)*x3 )
      b = -( ((x2-x1)*x3**3 + (x1**3-x2**3)*x3 + x1*x2**3-x1**3*x2)*y4 + &
             ((x1-x2)*x4**3 + (x2**3-x1**3)*x4 - x1*x2**3+x1**3*x2)*y3 + &
             ((x3-x1)*x4**3 + (x1**3-x3**3)*x4 + x1*x3**3-x1**3*x3)*y2 + &
             ((x2-x3)*x4**3 + (x3**3-x2**3)*x4 - x2*x3**3+x2**3*x3)*y1 )/( &
             ((x2-x1)*x3**2 + (x1**2-x2**2)*x3 + x1*x2**2-x1**2*x2)*x4**3 + &
             ((x1-x2)*x3**3 + (x2**3-x1**3)*x3 - x1*x2**3+x1**3*x2)*x4**2 + &
             ((x2**2-x1**2)*x3**3 + (x1**3-x2**3)*x3**2 + x1**2*x2**3 - x1**3*x2**2)*x4 + &
             (x1**2*x2-x1*x2**2)*x3**3 + &
             (x1*x2**3-x1**3*x2)*x3**2 + &
             (x1**3*x2**2-x1**2*x2**3)*x3 )
      c = ( ((x2**2-x1**2)*x3**3+(x1**3-x2**3)*x3**2+x1**2*x2**3-x1**3*x2**2)*y4 + &
            ((x1**2-x2**2)*x4**3+(x2**3-x1**3)*x4**2-x1**2*x2**3+x1**3*x2**2)*y3 + &
            ((x3**2-x1**2)*x4**3+(x1**3-x3**3)*x4**2+x1**2*x3**3-x1**3*x3**2)*y2 + &
            ((x2**2-x3**2)*x4**3+(x3**3-x2**3)*x4**2-x2**2*x3**3+x2**3*x3**2)* y1 )/( &
            ((x2-x1)*x3**2+(x1**2-x2**2)*x3+x1*x2**2-x1**2*x2)*x4**3+((x1-x2)*x3**3 + &
            (x2**3-x1**3)*x3-x1*x2**3+x1**3*x2)*x4**2+((x2**2 -x1**2)*x3**3+ &
            (x1**3-x2**3)*x3**2+x1**2*x2**3-x1**3*x2**2)*x4+( x1**2*x2-x1*x2**2)*x3**3+&
            (x1*x2**3-x1**3*x2)*x3**2+(x1**3*x2**2 -x1**2*x2**3)*x3)
      d = -( ((x1*x2**2-x1**2*x2)*x3**3 + (x1**3*x2-x1 *x2**3)*x3**2 + &
             (x1**2*x2**3-x1**3*x2**2)*x3)*y4 + ((x1**2*x2-x1*x2 **2)*x4**3+&
             (x1*x2**3-x1**3*x2)*x4**2+(x1**3*x2**2-x1**2*x2**3)* x4)*y3+&
             ((x1*x3**2-x1**2*x3)*x4**3+(x1**3*x3-x1*x3**3)*x4**2+&
             (x1**2*x3**3-x1**3*x3**2)*x4)*y2+((x2**2*x3-x2*x3**2)*x4**3+&
             (x2*x3 **3-x2**3*x3)*x4**2+(x2**3*x3**2-x2**2*x3**3)*x4)*y1)/(&
             ((x2-x1) *x3**2+(x1**2-x2**2)*x3+x1*x2**2-x1**2*x2)*x4**3+&
             ((x1-x2)*x3**3 +(x2**3-x1**3)*x3-x1*x2**3+x1**3*x2)*x4**2+&
             ((x2**2-x1**2)*x3**3 +(x1**3-x2**3)*x3**2+x1**2*x2**3-x1**3*x2**2)*x4+&
             (x1**2*x2-x1*x2**2)*x3**3+(x1*x2**3-x1**3*x2)*x3**2+&
             (x1**3*x2**2-x1**2*x2**3) *x3)
      y = a*x**3 + b*x**2 + c*x + d
   end function

   !**********************************************************************
   !> Swap a with b
   !**********************************************************************
   subroutine swap(a,b)
      implicit none
      double precision, intent(inout):: a,b
      double precision:: c
      c=a
      a=b
      b=c
   end subroutine

   !**********************************************************************
   !>
   !**********************************************************************
   subroutine saveReorderedModeSet(modeSet, nModes)
      implicit none
      integer, intent(in):: nModes
      double precision, intent(in):: modeSet(nModes)
      integer:: i
      open(unit=33, file=trim(fileToRead)//'-sorted', status='NEW')
      do i=1, nModes
         Write(33,*) i, modeSet(i)
      enddo
      close(unit=33)
   end subroutine

   !**********************************************************************
   !> Save, cleanup and shut down.
   !**********************************************************************
   subroutine cleanup()
      implicit none
      close(unit=unitFileList)
   end subroutine

   !**********************************************************************
   !> Cleanly aborts operations Writing an error message.
   !**********************************************************************
   subroutine MTabort(info)
      implicit none
      integer, intent(in):: info
      Write(*,*) "Aborting: error = ", info
      stop 1
   end subroutine

end program modeTracker
! vim: tabstop=3:softtabstop=3:shiftwidth=3:expandtab
